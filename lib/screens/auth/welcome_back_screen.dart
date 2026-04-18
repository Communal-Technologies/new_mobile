import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/numeric_keypad.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
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
import 'package:communal_mobile/routes/app_routes.dart';

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
  String? _lastProcessedError; // Track last processed error message to prevent duplicates
  bool _waitingForBackendValidation = false; // CRITICAL: Track if we're waiting for backend password validation
  bool _isLoadingUserInfo = false; // Track if user info is currently being loaded to prevent duplicate calls

  @override
  void initState() {
    super.initState();
    _currentMethod = widget.method;
    _authRepository = getIt<AuthRepository>();
    _waitingForBackendValidation = false; // Always start with false - no pending validation
    _isAuthenticating = false; // Always start with false
    
    // CRITICAL: For app lock, ONLY load login from secure storage (no API calls)
    // This prevents rebuilds and ensures error messages persist
    if (widget.isAppLock) {
      _loadUserLoginFromStorage().then((_) {
        // Only check biometric after login is loaded to prevent flicker
        // Use a small delay to ensure _user is set before checking
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) {
            _checkBiometricAvailability();
          }
        });
      });
    } else {
      // Only for fresh login, load user info from API
      _loadUserInfo();
      _checkBiometricAvailability();
    }
    
    // CRITICAL: If app is locked, ensure flags are reset
    if (widget.isAppLock) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        final securityCubit = context.read<SecurityCubit>();
        
        // CRITICAL: If app is already unlocked, don't show lock screen
        // This prevents showing lock screen after successful unlock
        if (securityCubit.state != SecurityState.locked) {
          return;
        }
        
        // Only call setState if flags actually need to change
        final needsReset = _waitingForBackendValidation || _isAuthenticating;
        if (needsReset) {
          setState(() {
            _waitingForBackendValidation = false;
            _isAuthenticating = false;
          });
        }
        
        // CRITICAL: For app lock, DO NOT reload user info (no API calls)
        // Login is already loaded from secure storage in _loadUserLoginFromStorage()
      });
    }
  }
  
  /// Load only login from secure storage (for app lock - no API calls)
  /// CRITICAL: This should ONLY be called once in initState for app lock
  /// It should NEVER be called again to prevent flickering/rebuilds
  Future<void> _loadUserLoginFromStorage() async {
    // CRITICAL: Prevent duplicate calls that cause flickering
    if (_isLoadingUserInfo) {
      return;
    }
    
    _isLoadingUserInfo = true;
    try {
      final storedLogin = await _secureStorage.read(key: 'login');
      if (mounted && storedLogin != null && storedLogin.isNotEmpty) {
        // CRITICAL: Only update if _user is null or login is different
        // This prevents unnecessary rebuilds and flickering
        // Also check if login is empty to handle edge cases
        if (_user == null || _user!.login != storedLogin || _user!.login.isEmpty) {
          setState(() {
            _user = UserModel(
              id: '0',
              name: storedLogin,
              login: storedLogin,
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading login from storage: $e');
    } finally {
      _isLoadingUserInfo = false;
    }
  }

  Future<void> _loadUserInfo() async {
    // Prevent duplicate calls
    if (_isLoadingUserInfo) {
      return;
    }
    
    _isLoadingUserInfo = true;
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
          _isLoadingUserInfo = false;
          return; // Successfully loaded from token
        }
      }
      
      // If no token (app is locked), try to get login from secure storage
      // and create a minimal user object for display
      // CRITICAL: Always load from secure storage if _user is null or login is empty
      // This ensures user data is preserved even after rebuilds (e.g., after wrong PIN)
      final storedLogin = await _secureStorage.read(key: 'login');
      if (mounted && storedLogin != null && storedLogin.isNotEmpty) {
        // Always update if _user is null or login is different
        // This ensures user data is preserved after rebuilds
        if (_user == null || _user!.login != storedLogin || _user!.login.isEmpty) {
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
      } else if (mounted && _user == null) {
        // If no login in storage and _user is null, log a warning
      }
    } catch (e) {
      // Failed to load user info, continue without it
    } finally {
      _isLoadingUserInfo = false;
    }
  }

  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await BiometricService.isBiometricAvailable();
    final biometricName = await BiometricService.getBiometricName();
    
    if (mounted) {
      // CRITICAL: For app lock, minimize setState calls to prevent flicker
      // Only update if values actually changed
      final shouldUpdate = _isBiometricAvailable != isAvailable || _biometricName != biometricName;
      
      if (shouldUpdate) {
        if (widget.isAppLock) {
          // For app lock, NEVER call setState during authentication to prevent flicker
          // Just update values - they'll be used on next natural rebuild
          _isBiometricAvailable = isAvailable;
          _biometricName = biometricName;
          // CRITICAL: Don't call setState - prevents email flicker during PIN entry/validation
        } else {
          // Fresh login - always update with setState
          setState(() {
            _isBiometricAvailable = isAvailable;
            _biometricName = biometricName;
          });
        }
      }
      
      // CRITICAL: For app lock, we don't have hasSecurityPin info (no API call)
      // So we can't auto-attempt biometric - user must manually choose it
      // Only auto-attempt biometric for fresh login where we have full user info
      if (!widget.isAppLock) {
        // Only auto-attempt biometric if:
        // 1. Biometric is available on device
        // 2. User has security pin set (hasSecurityPin from backend)
        // 3. We're not already authenticating
        // 4. This is fresh login (not app lock)
        if (isAvailable && _user?.hasSecurityPin == true && !_isAuthenticating) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && !_isAuthenticating) {
              _attemptBiometricAuth();
            }
          });
        }
      }
      // For app lock: Don't auto-attempt biometric (no hasSecurityPin info)
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
  /// CRITICAL: This method should always return a masked login, even if _user is null
  /// It will try multiple sources: _user.login, widget.phoneNumber, secure storage
  String _getMaskedLogin() {
    // First, try _user.login
    if (_user?.login != null && _user!.login.isNotEmpty) {
      return _maskString(_user!.login);
    }
    
    // Second, try widget.phoneNumber
    if (widget.phoneNumber.isNotEmpty) {
      return _maskString(widget.phoneNumber);
    }

    // Third: active session still has login (e.g. idle lock before storage read completes)
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.login.isNotEmpty) {
        return _maskString(authState.login);
      }
    } catch (_) {}
    
    // Fourth: rely on _loadUserLoginFromStorage / _loadUserInfo to set _user
    return '****';
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
              
              // CRITICAL: Do NOT unlock SecurityCubit - just clear data and navigate
              // Unlocking would cause SecurityWrapper to rebuild and show dashboard
              // We want to navigate to welcome screen, not unlock the app
              
              // Step 1: Clear all data first
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                await _secureStorage.delete(key: 'token');
                await _secureStorage.delete(key: 'login');
              } catch (e) {
                // Continue even if clearing fails
              }
              
              // Step 2: Dispatch logout (this will emit AuthUnauthenticated)
              context.read<AuthBloc>().add(LogoutRequested());
              
              // Step 3: Navigate using global appRouter
              // Use a short delay to ensure AuthBloc state is updated
              await Future.delayed(const Duration(milliseconds: 200));
              try {
                // Use global appRouter directly - works even when app is locked
                appRouter.go('/welcome');
              } catch (e) {
                // Retry after delay if first attempt fails
                await Future.delayed(const Duration(milliseconds: 200));
                try {
                  appRouter.go('/welcome');
                } catch (e2) {
                  // If navigation still fails, try one more time
                  await Future.delayed(const Duration(milliseconds: 200));
                  appRouter.go('/welcome');
                }
              }
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
      return '*' * input.length;
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
          _waitingForBackendValidation = false;
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
      
      // One setState so fullscreen loader shows immediately (fresh login is not SecurityState.locked).
      setState(() {
        _isAuthenticating = true;
        _waitingForBackendValidation = true;
      });
      
      // Dispatch login request - backend MUST validate password
      // If backend accepts wrong password, that's a backend bug - but we'll add extra safety checks
      if (!mounted) return;
      context.read<AuthBloc>().add(LoginRequested(
        login: login,
        password: _password,
      ));
      
    } catch (e) {
      setState(() {
        _isAuthenticating = false;
        _waitingForBackendValidation = false;
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

    return BlocListener<SecurityCubit, SecurityState>(
      listenWhen: (previous, current) {
        // Only listen when app unlocks (for fresh login navigation)
        if (!widget.isAppLock && previous == SecurityState.locked && current == SecurityState.unlocked) {
          return true;
        }
        return false;
      },
      listener: (context, state) {
        // For fresh login (not app lock), navigate to home when SecurityCubit unlocks
        if (!widget.isAppLock && state == SecurityState.unlocked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              try {
                context.go('/home');
              } catch (e) {
              }
            }
          });
        }
      },
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) {
        // CRITICAL: Only listen to AuthAuthenticated if ALL conditions are met:
        // 1. We're waiting for backend validation (_waitingForBackendValidation = true)
        // 2. Previous state was AuthVerifyingCredentials (PIN/password request in flight; not plain
        //    AuthLoading, which compares equal across emissions and can skip the transition we need)
        // 3. We're currently authenticating (_isAuthenticating = true)
        // This ensures we ONLY unlock when backend validates the password, not from cached tokens
        if (current is AuthAuthenticated) {
          final isValid = _waitingForBackendValidation && 
                          previous is AuthVerifyingCredentials && 
                          _isAuthenticating;
          if (isValid) {
            _lastProcessedError = null; // Clear error tracking on success
            return true;
          } else {
            return false; // Ignore - this AuthAuthenticated is from cached token, not password validation
          }
        } else if (current is AuthFailure) {
          // Only process if we're waiting for validation AND previous was verifying
          if (_waitingForBackendValidation && previous is AuthVerifyingCredentials) {
            if (_lastProcessedError != current.error) {
              _lastProcessedError = current.error;
              return true;
            }
            return false; // Already processed this error
          }
          return false;
        }
        return false;
      },
      listener: (context, state) {
        // Handle authentication responses
        if (state is AuthAuthenticated) {
          // CRITICAL SECURITY CHECK: Only unlock if ALL conditions are met:
          // 1. We're waiting for backend validation (_waitingForBackendValidation = true)
          // 2. BlocListener listenWhen already required AuthVerifyingCredentials → this success
          // 3. For app lock: app must be locked (user is unlocking)
          // This prevents unlocking from cached tokens or other sources
          if (!_waitingForBackendValidation) {
            return; // Don't unlock - this is from cached token, not password validation
          }
          
          // CRITICAL: Double-check that we're actually authenticating (not from stale state)
          if (!_isAuthenticating) {
            _waitingForBackendValidation = false;
            return;
          }
          
          // Splash can open /welcome-back with isAppLock while SecurityCubit is still unlocked.
          // Only require "was locked" for the idle-lock overlay path, not for that splash case.
          final securityCubit = context.read<SecurityCubit>();
          final wasSecurityLocked = securityCubit.state == SecurityState.locked;

          _waitingForBackendValidation = false; // Clear the flag IMMEDIATELY to prevent race conditions

          // Clear PIN UI and loader: same for true app-idle-lock and splash "resume session" flows.
          _isAuthenticating = false;
          _password = '';
          _pinController.clear();
          _passwordError = null;
          if (mounted) {
            setState(() {});
          }

          if (widget.isAppLock && wasSecurityLocked) {
            debugPrint('📊   🔓 WELCOME BACK - Unlocking app after successful PIN validation');
            securityCubit.unlockApp();
            securityCubit.recordActivity();
          } else {
            securityCubit.recordActivity();
          }
          
          // Go to home when we're on the shell route (login → welcome-back, or splash with token).
          // When idle-lock overlay showed WelcomeBackScreen inside SecurityWrapper, security was
          // locked — stay on current shell route and let SecurityWrapper reveal the dashboard.
          if (!widget.isAppLock || !wasSecurityLocked) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                try {
                  context.go('/home');
                } catch (e) {
                  Future.delayed(const Duration(milliseconds: 50), () {
                    if (mounted) {
                      try {
                        context.go('/home');
                      } catch (e2) {
                      }
                    }
                  });
                }
              }
            });
          } else {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final currentState = securityCubit.state;
                debugPrint('📊   🔓 WELCOME BACK - PostFrameCallback 1: SecurityCubit state = $currentState');
                if (currentState == SecurityState.unlocked) {
                  debugPrint('📊   ✅ SecurityCubit is unlocked - SecurityWrapper should show dashboard');
                  securityCubit.unlockApp();
                  securityCubit.recordActivity();
                } else {
                  debugPrint('📊   ⚠️ SecurityCubit still locked after unlock - forcing unlock again');
                  securityCubit.unlockApp();
                  securityCubit.recordActivity();
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    final stateAfterDelay = securityCubit.state;
                    debugPrint('📊   🔓 WELCOME BACK - PostFrameCallback 2: SecurityCubit state = $stateAfterDelay');
                    if (stateAfterDelay == SecurityState.unlocked) {
                      debugPrint('📊   ✅ SecurityCubit confirmed unlocked - SecurityWrapper MUST show dashboard');
                      securityCubit.unlockApp();
                    }
                  }
                });
              }
            });
          }
        } else if (state is AuthFailure) {
          // Authentication failed - backend rejected the password
          _waitingForBackendValidation = false; // Clear the flag
          
          // CRITICAL: Handle differently for app lock vs fresh login
          if (widget.isAppLock) {
            // App lock scenario - ensure app stays locked
            // CRITICAL: DO NOT call lockApp() if already locked - it causes rebuilds and flickering
            // The app is already locked, we just need to show the error
            final securityCubit = context.read<SecurityCubit>();
            
            // CRITICAL: Only lock if not already locked
            // But use isIdleTimeout=true to preserve token
            // This ensures token is NOT deleted, so app shows lock screen on restart
            if (securityCubit.state != SecurityState.locked) {
              securityCubit.lockApp(isIdleTimeout: true); // Preserve token
            }
            // If already locked, do nothing - prevents rebuild/flicker
          } else {
            // Fresh login scenario - DO NOT lock the app
            // Just show the error and stay on the same screen
            // Locking the app would cause SecurityWrapper to rebuild and show lock screen,
            // which would lose the error state and user data
          }
          
          // CRITICAL: Show error message - this works for both app lock and fresh login
          // For app lock, use a minimal setState that ONLY updates error state
          // DO NOT modify _user or any other state that affects email display
          if (widget.isAppLock) {
            // App lock - preserve _user to prevent email flicker
            // Store current _user to ensure it doesn't change
            final currentUser = _user;
            _isAuthenticating = false;
            _password = '';
            _pinController.clear();
            _passwordError = state.error;
            // Use setState but ensure _user remains unchanged
            if (mounted) {
              setState(() {
                // Only update error-related state
                // CRITICAL: Preserve _user to prevent email flicker
                if (_user != currentUser) {
                  _user = currentUser; // Restore if somehow changed
                }
              });
            }
          } else {
            // Fresh login - use setState normally
            setState(() {
              _isAuthenticating = false;
              _password = ''; // Clear password on incorrect entry
              _pinController.clear(); // Clear controller
              _passwordError = state.error; // Show backend error message
            });
          }
          
          // CRITICAL: For app lock, DO NOT reload user info (no API calls)
          // Login is already loaded from secure storage and will persist
          // Only reload for fresh login (not app lock)
          if (!widget.isAppLock) {
            _loadUserInfo();
          }
          
          // CRITICAL: Do NOT navigate - stay on current screen
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for light background
        statusBarBrightness: Brightness.light, // Light status bar for iOS
      ),
      child: BlocListener<SecurityCubit, SecurityState>(
        listenWhen: (previous, current) {
          // Listen when app becomes unlocked to force hide loader
          return previous == SecurityState.locked && current == SecurityState.unlocked;
        },
        listener: (context, securityState) {
          // CRITICAL: When app becomes unlocked, force clear loader immediately
          if (securityState == SecurityState.unlocked && _isAuthenticating) {
            if (mounted) {
              setState(() {
                _isAuthenticating = false; // Force clear loader
              });
            }
          }
        },
        child: BlocBuilder<SecurityCubit, SecurityState>(
          // Rebuild on every security state change so loader tracks lock/unlock.
          // Parent setState (PIN submit) already rebuilds this subtree; omitting a narrow
          // buildWhen avoids missing frames when only local auth flags change.
          builder: (context, securityState) {
            // Rebuild when AuthBloc hits verifying / result so loader appears even if the first
            // setState frame is skipped before the bloc processes LoginRequested.
            final _ = context.watch<AuthBloc>().state;
            // PIN API in flight, or biometric / PIN while security lock UI is showing.
            final shouldShowLoader = _waitingForBackendValidation ||
                (_isAuthenticating &&
                    securityState == SecurityState.locked);
            
            return Stack(
            fit: StackFit.expand,
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
          // Loader overlay when authenticating AND app is still locked
          // CRITICAL: Hide loader immediately when app becomes unlocked
          if (shouldShowLoader)
            Positioned.fill(
              child: const LoaderOverlay(),
            ),
        ],
      );
          },
        ),
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
                
                
                // Navigate with login if available
                final Map<String, dynamic> extra = {};
                if (login.isNotEmpty) {
                  extra['preFilledContact'] = login;
                }
                
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

