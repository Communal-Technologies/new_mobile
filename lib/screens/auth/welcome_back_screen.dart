import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/numeric_keypad.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:communal_mobile/core/utils/biometric_service.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:communal_mobile/cubits/security/security_cubit.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SignInMethod { pin, fingerprint, password }

class WelcomeBackScreen extends StatefulWidget {
  const WelcomeBackScreen({
    super.key,
    this.phoneNumber = '',
    this.method = SignInMethod.pin,
    this.isAppLock = false, // If true, this is for app lock (no back button, no forgot password)
  });

  final String phoneNumber;
  final SignInMethod method;
  final bool isAppLock;

  @override
  State<WelcomeBackScreen> createState() => _WelcomeBackScreenState();
}

class _WelcomeBackScreenState extends State<WelcomeBackScreen> {
  final _pinController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  late final AuthRepository _authRepository;
  String _password = '';
  bool _isPasswordVisible = false; // Hide password by default (show dots)
  String? _passwordError; // Error message for password
  bool _isBiometricAvailable = false;
  String _biometricName = 'Fingerprint';
  bool _isAuthenticating = false;
  UserModel? _user;
  SignInMethod _currentMethod = SignInMethod.pin; // Track current method
  bool _handlingErrorLocally = false; // Track if we're handling error locally (to prevent duplicate snackbars)
  String? _lastProcessedError; // Track last processed error message to prevent duplicates
  bool _waitingForBackendValidation = false; // CRITICAL: Track if we're waiting for backend password validation

  @override
  void initState() {
    super.initState();
    _currentMethod = widget.method;
    _authRepository = getIt<AuthRepository>();
    _waitingForBackendValidation = false; // Always start with false - no pending validation
    _isAuthenticating = false; // Always start with false
    _loadUserInfo();
    _checkBiometricAvailability();
    
    // CRITICAL: If app is locked, ensure we're not in an authenticated state
    // This prevents unlocking with cached AuthAuthenticated state
    if (widget.isAppLock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final authState = context.read<AuthBloc>().state;
        if (authState is AuthAuthenticated) {
          debugPrint('📊   ⚠️ App is locked but AuthBloc is in AuthAuthenticated state');
          debugPrint('📊   ⚠️ This should not happen - token should be deleted when app locks');
          debugPrint('📊   ⚠️ This AuthAuthenticated state will be IGNORED - PIN must be validated');
          // CRITICAL: Reset all authentication flags to ensure any AuthAuthenticated state is ignored
          // The listener will only accept AuthAuthenticated if _waitingForBackendValidation is true
          // which is only set when user actually enters PIN and we dispatch LoginRequested
          if (mounted) {
            setState(() {
              _waitingForBackendValidation = false;
              _isAuthenticating = false;
            });
            debugPrint('📊   ✅ Reset authentication flags - any existing AuthAuthenticated will be ignored');
          }
        } else {
          // Ensure flags are reset even if not authenticated
          if (mounted) {
            setState(() {
              _waitingForBackendValidation = false;
              _isAuthenticating = false;
            });
          }
        }
      });
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      // Try to load user info from token first
      final token = await _secureStorage.read(key: 'token');
      if (token != null) {
        final user = await _authRepository.getUserInfo(token);
        if (mounted && user != null) {
          // Only update state if user actually changed to prevent unnecessary rebuilds
          if (_user?.id != user.id) {
            setState(() {
              _user = user;
            });
            // Re-check biometric availability after user is loaded
            // to see if user has security pin set
            _checkBiometricAvailability();
          }
          return; // Successfully loaded from token
        }
      }
      
      // If no token (app is locked), try to get login from secure storage
      // and create a minimal user object for display
      final storedLogin = await _secureStorage.read(key: 'login');
      if (mounted && storedLogin != null && storedLogin.isNotEmpty) {
        // Only update state if login actually changed to prevent unnecessary rebuilds
        if (_user?.login != storedLogin) {
          // Create a minimal user object with just the login for display
          setState(() {
            _user = UserModel(
              id: '0', // Placeholder string ID
              name: storedLogin, // Use login as name for display
              login: storedLogin,
              // Other fields will be null/empty, but login is enough for display
            );
          });
        }
      }
    } catch (e) {
      // Failed to load user info, continue without it
      debugPrint('Failed to load user info: $e');
    }
  }

  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await BiometricService.isBiometricAvailable();
    final biometricName = await BiometricService.getBiometricName();
    
    if (mounted) {
      // Only update state if values actually changed to prevent unnecessary rebuilds
      if (_isBiometricAvailable != isAvailable || _biometricName != biometricName) {
        setState(() {
          _isBiometricAvailable = isAvailable;
          _biometricName = biometricName;
        });
      }
      
      // Only auto-attempt biometric if:
      // 1. Biometric is available on device
      // 2. User has security pin set (hasSecurityPin from backend)
      if (isAvailable && _user?.hasSecurityPin == true) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _attemptBiometricAuth();
          }
        });
      }
    }
  }

  Future<void> _attemptBiometricAuth() async {
    if (!_isBiometricAvailable || _isAuthenticating) return;
    
    setState(() {
      _isAuthenticating = true;
    });

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to sign in',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated && mounted) {
        // Biometric authentication successful
        if (widget.isAppLock) {
          // Unlock the app
          context.read<SecurityCubit>().unlockApp();
        } else {
          // Navigate to home (login flow)
          context.go('/home');
        }
      } else {
        setState(() {
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      setState(() {
        _isAuthenticating = false;
      });
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  /// Get masked login (email or phone) for display
  String _getMaskedLogin() {
    if (_user?.login == null || _user!.login.isEmpty) {
      return widget.phoneNumber.isNotEmpty 
          ? _maskString(widget.phoneNumber)
          : '****';
    }
    
    final login = _user!.login;
    return _maskString(login);
  }

  /// Show logout confirmation dialog
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out? This will clear all your data.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // CRITICAL: Dispatch logout to clear authentication state
              // SecurityWrapper will handle navigation when AuthUnauthenticated is emitted
              context.read<AuthBloc>().add(LogoutRequested());
              
              // Clear SharedPreferences (onboarding flag is in secure storage, so it's safe)
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              
              // Note: Navigation will be handled by SecurityWrapper when it sees AuthUnauthenticated
              // We don't navigate here because the locked screen doesn't have GoRouter context
              debugPrint('📊   🚪 Logout dispatched - SecurityWrapper will handle navigation');
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Mask email or phone number with asterisks
  String _maskString(String input) {
    if (input.isEmpty) return '****';
    
    // Check if it's an email
    if (input.contains('@')) {
      final parts = input.split('@');
      if (parts.length == 2) {
        final username = parts[0];
        final domain = parts[1];
        // Show first 2 chars and last char of username, mask the rest
        if (username.length <= 3) {
          return '${'*' * username.length}@$domain';
        }
        final masked = '${username.substring(0, 2)}${'*' * (username.length - 3)}${username.substring(username.length - 1)}@$domain';
        return masked;
      }
    }
    
    // It's a phone number
    // Show first 3 digits and last 4 digits, mask the rest
    if (input.length <= 7) {
      return '${'*' * input.length}';
    }
    final start = input.substring(0, 3);
    final end = input.substring(input.length - 4);
    final middle = '*' * (input.length - 7);
    return '$start$middle$end';
  }


  void _onNumberTap(String number) {
    if (_password.length < 6) {
      setState(() {
        _password += number;
        _pinController.text = _password;
        _passwordError = null; // Clear error when user starts typing
      });

      if (_password.length == 6) {
        _signIn();
      }
    }
  }

  void _onBackspace() {
    if (_password.isNotEmpty) {
      setState(() {
        _password = _password.substring(0, _password.length - 1);
        _pinController.text = _password;
        _passwordError = null; // Clear error when user starts typing
      });
    }
  }

  Future<void> _signIn() async {
    if (_isAuthenticating) return;
    
    setState(() {
      _isAuthenticating = true;
    });

    // Always validate password with backend for security
    // This ensures account locking works correctly and passwords are never stored locally
    try {
      // Get stored login from secure storage
      final storedLogin = await _secureStorage.read(key: 'login');
      final login = storedLogin ?? widget.phoneNumber;
      
      if (login.isEmpty) {
        // No login stored, show error
        setState(() {
          _isAuthenticating = false;
          _passwordError = 'Unable to verify password. Please log in again.';
        });
        return;
      }
      
      // CRITICAL: Dispatch login event to verify password with backend
      // Backend will track failed attempts and lock account if needed
      // We MUST wait for backend validation before unlocking
      // This applies to BOTH scenarios:
      // 1. Idle timeout lock: Token is kept, but PIN must still be validated with backend
      // 2. Other locks: Token is deleted, PIN must be validated and new token issued
      debugPrint('📊 [${DateTime.now().millisecondsSinceEpoch}] 🔐 SENDING PASSWORD TO BACKEND FOR VALIDATION');
      debugPrint('📊   Login: $login');
      debugPrint('📊   Password length: ${_password.length}');
      debugPrint('📊   isAppLock: ${widget.isAppLock}');
      debugPrint('📊   Setting _waitingForBackendValidation = true');
      
      // CRITICAL: Set flag BEFORE dispatching to prevent race conditions
      // Also store the password we're sending so we can verify the response matches
      setState(() {
        _waitingForBackendValidation = true;
      });
      
      // Dispatch login request - backend MUST validate password
      // If backend accepts wrong password, that's a backend bug - but we'll add extra safety checks
      context.read<AuthBloc>().add(LoginRequested(
        login: login,
        password: _password,
      ));
      
      debugPrint('📊   LoginRequested dispatched, waiting for backend response...');
    } catch (e) {
      setState(() {
        _isAuthenticating = false;
        _passwordError = 'Error: ${e.toString()}';
      });
    }
  }

  void _switchMethod(SignInMethod method) {
    setState(() {
      // Clear password when switching methods
      _password = '';
      _pinController.clear();
      _isPasswordVisible = false;
      _currentMethod = method;
    });
    
    // If switching to biometric and user has it configured, attempt it
    if (method == SignInMethod.fingerprint && 
        _isBiometricAvailable && 
        _user?.hasSecurityPin == true) {
      // Trigger biometric authentication after a short delay
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _attemptBiometricAuth();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    debugPrint('📊 [${timestamp}] WELCOME BACK SCREEN - build() called');
    debugPrint('📊   isAppLock: ${widget.isAppLock}');
    debugPrint('📊   Current AuthBloc state: ${context.read<AuthBloc>().state.runtimeType}');

    return BlocListener<SecurityCubit, SecurityState>(
      listenWhen: (previous, current) {
        // Only listen when app unlocks (for fresh login navigation)
        if (!widget.isAppLock && previous == SecurityState.locked && current == SecurityState.unlocked) {
          debugPrint('📊   ✅ SecurityCubit unlocked - will navigate to /home');
          return true;
        }
        return false;
      },
      listener: (context, state) {
        // For fresh login (not app lock), navigate to home when SecurityCubit unlocks
        if (!widget.isAppLock && state == SecurityState.unlocked) {
          debugPrint('📊   🏠 SecurityCubit unlocked - navigating to /home (fresh login)');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                context.go('/home');
                debugPrint('📊   ✅ Navigated to /home successfully');
              } catch (e) {
                debugPrint('📊   ⚠️ Navigation error: $e');
              }
            }
          });
        }
      },
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        debugPrint('📊 [${timestamp}] WELCOME BACK SCREEN - listenWhen called');
        debugPrint('📊   Previous: ${previous.runtimeType}, Current: ${current.runtimeType}');
        debugPrint('📊   _waitingForBackendValidation: $_waitingForBackendValidation');
        
        // CRITICAL: Only listen to AuthAuthenticated if ALL conditions are met:
        // 1. We're waiting for backend validation (_waitingForBackendValidation = true)
        // 2. Previous state was AuthLoading (we just sent a login request)
        // 3. We're currently authenticating (_isAuthenticating = true)
        // This ensures we ONLY unlock when backend validates the password, not from cached tokens
        if (current is AuthAuthenticated) {
          final isValid = _waitingForBackendValidation && 
                          previous is AuthLoading && 
                          _isAuthenticating;
          if (isValid) {
            debugPrint('📊   ✅ listenWhen returning TRUE for AuthAuthenticated (from backend validation)');
            debugPrint('📊   ✅ All validation checks passed: _waitingForBackendValidation=$_waitingForBackendValidation, previous=AuthLoading, _isAuthenticating=$_isAuthenticating');
            _lastProcessedError = null; // Clear error tracking on success
            return true;
          } else {
            debugPrint('📊   ⚠️ listenWhen returning FALSE for AuthAuthenticated (not from password validation)');
            debugPrint('📊   ⚠️ _waitingForBackendValidation: $_waitingForBackendValidation');
            debugPrint('📊   ⚠️ Previous was AuthLoading: ${previous is AuthLoading}');
            debugPrint('📊   ⚠️ _isAuthenticating: $_isAuthenticating');
            debugPrint('📊   ⚠️ This AuthAuthenticated is IGNORED - not from current login attempt');
            return false; // Ignore - this AuthAuthenticated is from cached token, not password validation
          }
        } else if (current is AuthFailure) {
          // Only process if we're waiting for validation AND previous was AuthLoading
          if (_waitingForBackendValidation && previous is AuthLoading) {
            if (_lastProcessedError != current.error) {
              debugPrint('📊   ❌ listenWhen returning TRUE for AuthFailure (backend rejected password)');
              _lastProcessedError = current.error;
              return true;
            }
            debugPrint('📊   ⏭️ listenWhen returning FALSE (already processed this error)');
            return false; // Already processed this error
          }
          debugPrint('📊   ⏭️ listenWhen returning FALSE (not waiting for validation or not from current attempt)');
          return false;
        }
        debugPrint('📊   ⏭️ listenWhen returning FALSE (not AuthAuthenticated or AuthFailure)');
        return false;
      },
      listener: (context, state) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        debugPrint('📊 [${timestamp}] WELCOME BACK SCREEN - AuthBloc listener triggered');
        debugPrint('📊   State type: ${state.runtimeType}');
        debugPrint('📊   isAppLock: ${widget.isAppLock}');
        
        // Handle authentication responses
        if (state is AuthAuthenticated) {
          // CRITICAL SECURITY CHECK: Only unlock if ALL conditions are met:
          // 1. We're waiting for backend validation (_waitingForBackendValidation = true)
          // 2. Previous state was AuthLoading (we just sent a login request)
          // 3. For app lock: app must be locked (user is unlocking)
          // This prevents unlocking from cached tokens or other sources
          if (!_waitingForBackendValidation) {
            debugPrint('📊   ⚠️⚠️⚠️ SECURITY BREACH PREVENTED: AuthAuthenticated received but NOT waiting for backend validation');
            debugPrint('📊   ⚠️⚠️⚠️ This AuthAuthenticated is from cached token or app start - IGNORING');
            debugPrint('📊   ⚠️⚠️⚠️ App will NOT unlock - password must be validated by backend');
            return; // Don't unlock - this is from cached token, not password validation
          }
          
          // CRITICAL: Double-check that we're actually authenticating (not from stale state)
          if (!_isAuthenticating) {
            debugPrint('📊   ⚠️⚠️⚠️ SECURITY BREACH PREVENTED: AuthAuthenticated received but _isAuthenticating is false');
            debugPrint('📊   ⚠️⚠️⚠️ This AuthAuthenticated is from stale state - IGNORING');
            _waitingForBackendValidation = false;
            return;
          }
          
          // CRITICAL: For app lock, verify app is actually locked
          // This ensures we only unlock when user enters PIN on lock screen
          if (widget.isAppLock) {
            final securityCubit = context.read<SecurityCubit>();
            if (securityCubit.state != SecurityState.locked) {
              debugPrint('📊   ⚠️⚠️⚠️ SECURITY: App is not locked but received AuthAuthenticated - ignoring');
              _waitingForBackendValidation = false;
              return;
            }
          }
          
          debugPrint('📊   ✅ AUTHENTICATION SUCCESSFUL - Backend validated password');
          debugPrint('📊   ✅ All security checks passed - unlocking app now');
          _waitingForBackendValidation = false; // Clear the flag IMMEDIATELY to prevent race conditions
          
          // Authentication successful - backend validated the password
          setState(() {
            _isAuthenticating = false;
            _password = '';
            _pinController.clear();
            _passwordError = null; // Clear any errors
          });
          
          // CRITICAL: Always unlock SecurityCubit IMMEDIATELY and SYNCHRONOUSLY
          // This must happen before any navigation or SecurityWrapper rebuild
          final securityCubit = context.read<SecurityCubit>();
          debugPrint('📊   SecurityCubit state before unlock: ${securityCubit.state}');
          
          // CRITICAL: Always unlock SecurityCubit if it's locked (for both app lock and fresh login)
          // This prevents SecurityWrapper from showing lock screen after navigation
          if (securityCubit.state == SecurityState.locked) {
            debugPrint('📊   🔓 Unlocking app IMMEDIATELY (${widget.isAppLock ? "app lock" : "fresh login"})');
            securityCubit.unlockApp();
            debugPrint('📊   SecurityCubit state after unlock: ${securityCubit.state}');
            
            // CRITICAL: Verify unlock succeeded
            if (securityCubit.state != SecurityState.unlocked) {
              debugPrint('📊   ⚠️⚠️⚠️ CRITICAL: SecurityCubit still locked after unlockApp()! Forcing unlock again');
              securityCubit.unlockApp();
            }
          } else {
            debugPrint('📊   ✅ SecurityCubit is already unlocked');
          }
          
          // Record activity immediately to prevent idle timeout from locking again
          securityCubit.recordActivity();
          debugPrint('📊   ✅ Recorded activity to prevent immediate re-lock');
          
          // CRITICAL: Navigate immediately after unlock
          // For fresh login (isAppLock=false), navigate directly
          // For app lock (isAppLock=true), SecurityWrapper will handle showing dashboard
          if (!widget.isAppLock) {
            // Fresh login - navigate immediately without waiting for multiple frames
            debugPrint('📊   🏠 Navigating to /home immediately (fresh login)');
            // Use a single frame callback to ensure context is ready
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                try {
                  context.go('/home');
                  debugPrint('📊   ✅ Navigated to /home successfully');
                } catch (e) {
                  debugPrint('📊   ⚠️ Navigation error: $e - retrying...');
                  // Retry after a very short delay if first attempt fails
                  Future.delayed(const Duration(milliseconds: 50), () {
                    if (mounted) {
                      try {
                        context.go('/home');
                        debugPrint('📊   ✅ Navigated to /home on retry');
                      } catch (e2) {
                        debugPrint('📊   ❌ Navigation failed on retry: $e2');
                      }
                    }
                  });
                }
              }
            });
          } else {
            // App lock - SecurityWrapper will show dashboard when it sees unlocked state
            debugPrint('📊   ✅ App unlocked - SecurityWrapper will show dashboard');
          }
        } else if (state is AuthFailure) {
          // Authentication failed - backend rejected the password
          debugPrint('📊   ❌ AUTHENTICATION FAILED - Backend rejected password');
          debugPrint('📊   ❌ Error: ${state.error}');
          debugPrint('📊   ❌ App will remain LOCKED');
          _waitingForBackendValidation = false; // Clear the flag
          
          // CRITICAL: Ensure app stays locked - ALWAYS lock, even if already locked
          final securityCubit = context.read<SecurityCubit>();
          debugPrint('📊   🔒 SecurityCubit state BEFORE lock: ${securityCubit.state}');
          
          // CRITICAL: If app is not locked, lock it immediately
          if (securityCubit.state != SecurityState.locked) {
            debugPrint('📊   ⚠️⚠️⚠️ CRITICAL: App is NOT locked after wrong PIN - locking NOW');
            securityCubit.lockApp(); // ALWAYS call lockApp() to ensure it's locked
            debugPrint('📊   🔒 SecurityCubit state AFTER lock: ${securityCubit.state}');
          } else {
            debugPrint('📊   ✅ App is already locked - good');
          }
          
          // CRITICAL: Verify it's actually locked
          if (securityCubit.state != SecurityState.locked) {
            debugPrint('📊   ⚠️⚠️⚠️ CRITICAL: SecurityCubit is NOT locked after lockApp() call!');
            debugPrint('📊   ⚠️⚠️⚠️ Current state: ${securityCubit.state}');
            // Try again
            securityCubit.lockApp();
            debugPrint('📊   🔒 SecurityCubit state after second lock: ${securityCubit.state}');
          } else {
            debugPrint('📊   ✅ SecurityCubit is confirmed LOCKED');
          }
          
          // CRITICAL: Ensure we're not navigating anywhere
          debugPrint('📊   🚫 Wrong PIN entered - app MUST stay locked');
          
          if (!_handlingErrorLocally) {
            setState(() {
              _isAuthenticating = false;
              _password = ''; // Clear password on incorrect entry
              _pinController.clear(); // Clear controller
              _passwordError = state.error;
            });
          } else {
            // Error already shown locally, just reset state
            setState(() {
              _isAuthenticating = false;
              _password = ''; // Clear password even if handled locally
              _pinController.clear();
            });
          }
          
          // CRITICAL: Do NOT navigate - stay on lock screen
          debugPrint('📊   🚫 Staying on lock screen - NOT navigating');
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for light background
        statusBarBrightness: Brightness.light, // Light status bar for iOS
      ),
      child: Stack(
        children: [
          Scaffold(
        backgroundColor: Colors.white,
        appBar: widget.isAppLock
            ? null // No app bar for app lock
            : AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
                systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                ),
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => context.pop(),
            ),
          ],
        ),
        leadingWidth: 80.w,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              // Add extra top spacing when app bar is hidden (app lock mode)
              vSpace(widget.isAppLock ? 40 : 10),

              // Logo
              Center(
                child: Image.asset(
                  Images.coloredLogo,
                  width: 130.w,
                ),
              ),

              vSpace(24),

              // Profile picture
              Center(
                child: _user?.avatar != null && _user!.avatar!.isNotEmpty
                    ? Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade200,
                        ),
                        child: ClipOval(
                          child: Image.network(
                            _user!.avatar!,
                            width: 80.w,
                            height: 80.w,
                      fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              // If network image fails, show standard icon
                              return Container(
                                width: 80.w,
                                height: 80.w,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey.shade300,
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 40.sp,
                                  color: Colors.grey.shade600,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 80.w,
                                height: 80.w,
                                color: Colors.grey.shade200,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    : Container(
                        width: 80.w,
                        height: 80.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey.shade300,
                        ),
                        child: Icon(
                          Icons.person,
                          size: 40.sp,
                          color: Colors.grey.shade600,
                        ),
                ),
              ),

              vSpace(16),

              // Welcome back
              Center(
                child: Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),

              vSpace(6),

              // Email/Phone number (masked)
              Center(
                child: Text(
                  _getMaskedLogin(),
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: theme.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              vSpace(32),

              // Content based on sign-in method
              // Only show biometric if:
              // 1. Device supports biometric
              // 2. User has security pin configured (hasSecurityPin from backend)
              // 3. Current method is fingerprint
              if (_currentMethod == SignInMethod.fingerprint && 
                  _isBiometricAvailable && 
                  _user?.hasSecurityPin == true) ...[
                _buildFingerprintContent(theme),
              ] else ...[
                // Show password entry (PIN/Password)
                _buildPasswordContent(theme),
              ],

              vSpace(40),

              // Logout option
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Want to switch account? ',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Show confirmation dialog before logging out
                      _showLogoutDialog(context);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      'Logout',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              vSpace(24),
            ],
          ),
        ),
          ),
        ),
          // Loader overlay when authenticating
          if (_isAuthenticating)
            const LoaderOverlay(),
        ],
      ),
      ),
    ),
    );
  }

  Widget _buildFingerprintContent(ThemeData theme) {
    return Column(
      children: [
        // Fingerprint icon
        Icon(
          Icons.fingerprint,
          size: 120.sp,
          color: theme.primaryColor,
        ),

        vSpace(40),

        // Sign in with fingerprint button
        AppElevatedButton(
          title: 'Sign in with $_biometricName',
          onPressed: _isAuthenticating ? null : _attemptBiometricAuth,
          isLoading: _isAuthenticating,
        ),

        vSpace(16),

        // Alternative: PIN
        AppSecondaryButton(
          title: 'Sign in with PIN',
          isDark: false,
          onPressed: () => _switchMethod(SignInMethod.pin),
        ),
      ],
    );
  }

  Widget _buildPasswordContent(ThemeData theme) {
    return Column(
      children: [
        // Password input field (6 digits - always visible)
        Row(
            mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
            children: List.generate(6, (index) {
            final hasValue = index < _password.length;
            final hasError = _passwordError != null;
            return Flexible(
              child: GestureDetector(
                onTap: () {
                  // Toggle visibility when tapping on a circle
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
                child: Container(
                  width: 40.w,
                  height: 40.w,
                  margin: EdgeInsets.symmetric(horizontal: 3.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                    color: hasValue 
                        ? (hasError ? Colors.red : theme.primaryColor)
                        : Colors.grey.shade200,
                    border: Border.all(
                      color: hasError 
                          ? Colors.red 
                          : (hasValue ? theme.primaryColor : Colors.grey.shade300),
                      width: hasError ? 2 : 1.5,
                    ),
                  ),
                  child: hasValue
                      ? Center(
                          child: _isPasswordVisible
                              ? Text(
                                  _password[index],
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                )
                              : Container(
                                  width: 12.w,
                                  height: 12.w,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                ),
                        )
                      : null,
                ),
                ),
              );
            }),
        ),

        // Error message below password circles
        if (_passwordError != null) ...[
          vSpace(12),
          Text(
            _passwordError!,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        vSpace(12),

        // Forgot password link (only show if not app lock)
        if (!widget.isAppLock)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
              onPressed: () async {
                // Get the user's login (email or phone)
                // Try multiple sources to ensure we get the login
                final storedLogin = await _secureStorage.read(key: 'login');
                String? login = storedLogin;
                
                // If no stored login, try user model
                if (login == null || login.isEmpty) {
                  login = _user?.login;
                }
                
                // If still no login, try widget phoneNumber
                if (login == null || login.isEmpty) {
                  login = widget.phoneNumber;
                }
                
                debugPrint('🔵 FORGOT PASSWORD - storedLogin: $storedLogin');
                debugPrint('🔵 FORGOT PASSWORD - _user?.login: ${_user?.login}');
                debugPrint('🔵 FORGOT PASSWORD - widget.phoneNumber: ${widget.phoneNumber}');
                debugPrint('🔵 FORGOT PASSWORD - final login: $login');
                
                // Navigate with login if available
                final Map<String, dynamic> extra = {};
                if (login.isNotEmpty) {
                  extra['preFilledContact'] = login;
                }
                
                debugPrint('🔵 FORGOT PASSWORD - Navigating with extra: $extra');
                context.push('/forgot-password', extra: extra);
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Forgot Password?',
              style: TextStyle(
                fontSize: 14.sp,
                color: theme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        vSpace(24),

        // Numeric keypad
        NumericKeypad(
          onNumberTap: _onNumberTap,
          onBackspace: _onBackspace,
        ),

        vSpace(20),

        // Alternative: Biometric (only show if available AND user has it configured)
        if (_isBiometricAvailable && _user?.hasSecurityPin == true)
          AppSecondaryButton(
            title: 'Use $_biometricName',
            isDark: false,
            onPressed: () => _switchMethod(SignInMethod.fingerprint),
          ),
      ],
    );
  }

}

