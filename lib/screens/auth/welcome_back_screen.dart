import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/numeric_keypad.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
import 'package:communal_mobile/core/utils/biometric_service.dart';
import 'package:communal_mobile/data/local/biometric_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart' as shared_prefs;
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
import 'package:communal_mobile/core/utils/dio_transport_user_message.dart';
import 'package:communal_mobile/cubits/splash/splash_cubit.dart';
import 'package:dio/dio.dart';
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
  
  /// Hydrate the in-memory `_user` for the lock screen from the active
  /// [AuthBloc] state. Audit M5: the legacy version of this method read
  /// the email/phone identifier from secureStorage so the lock screen could
  /// re-render it across rebuilds. We no longer persist that identifier;
  /// when the bloc still holds an [AuthAuthenticated] (idle-lock case)
  /// the resident `user` is the source. Cold-start lock with no resident
  /// state simply renders the generic "Welcome back" greeting.
  Future<void> _loadUserLoginFromStorage() async {
    if (_isLoadingUserInfo) return;
    _isLoadingUserInfo = true;
    try {
      if (!mounted) return;
      final auth = context.read<AuthBloc>().state;
      if (auth is AuthAuthenticated) {
        if (_user?.id != auth.user.id) {
          setState(() => _user = auth.user);
        }
      }
    } catch (_) {
      // Silent: no in-memory state means we render the generic greeting.
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
            // to see if user has security pin set. Fire-and-forget;
            // setState inside the call surfaces results when ready.
            // ignore: unawaited_futures
            _checkBiometricAvailability();
          }
          _isLoadingUserInfo = false;
          return; // Successfully loaded from token
        }
      }
      
      // Audit M5: no fallback to a stored identifier here either. If the
      // bloc holds AuthAuthenticated (idle-lock with active session), use
      // its user; otherwise leave `_user` null and render the generic
      // greeting.
      if (mounted) {
        final auth = context.read<AuthBloc>().state;
        if (auth is AuthAuthenticated && _user?.id != auth.user.id) {
          setState(() => _user = auth.user);
        }
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

    // Audit M38 Phase D: respect the user's "App Login" pref. If the
    // user disabled biometric for app-login in Settings (but kept it on
    // for transactions, or disabled it altogether), skip the prompt and
    // require PIN entry.
    final shared = await shared_prefs.SharedPreferences.getInstance();
    final prefs = BiometricPrefs(shared);
    if (!prefs.appLoginEnabled) return;

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

  /// Returns a masked email/phone for display below the "Welcome Back" header.
  ///
  /// Audit M5: this method NEVER reads from secure storage — that was the
  /// audit's actual attack surface (Keystore extraction reveals which
  /// account is logged in). All sources here are in-memory only:
  ///   1. `_user.login` — server-fetched UserModel from `/get-loggedin-user`
  ///   2. `widget.phoneNumber` — passed via the route extra at navigation time
  ///   3. `AuthBloc.state.login` — resident in-memory through idle-lock
  /// Renders `****` when none of the in-memory sources have a value (cold
  /// lock with no resident state).
  String _getMaskedLogin() {
    if (_user?.login != null && _user!.login.isNotEmpty) {
      return _maskString(_user!.login);
    }
    if (widget.phoneNumber.isNotEmpty) {
      return _maskString(widget.phoneNumber);
    }
    try {
      final authState = context.read<AuthBloc>().state;
      if (authState is AuthAuthenticated && authState.login.isNotEmpty) {
        return _maskString(authState.login);
      }
    } catch (_) {}
    return '****';
  }

  /// Mask email or phone number with asterisks.
  String _maskString(String input) {
    if (input.isEmpty) return '****';

    if (input.contains('@')) {
      final parts = input.split('@');
      if (parts.length == 2) {
        final username = parts[0];
        final domain = parts[1];
        // Fixed-width middle mask: always 5 asterisks, regardless of
        // username length. When the username has 5 chars or fewer there's
        // nothing to peek out around the mask, so substitute the whole
        // thing.
        if (username.length <= 5) {
          return '*****@$domain';
        }
        final revealed = username.length - 5;
        final startLen = (revealed + 1) ~/ 2; // bias to the start on odd
        final endLen = revealed - startLen;
        final start = username.substring(0, startLen);
        final end = endLen > 0
            ? username.substring(username.length - endLen)
            : '';
        return '$start*****$end@$domain';
      }
    }

    // Phone: keep the first 5 and last 2 digits visible, mask the middle.
    if (input.length <= 7) {
      return '*' * input.length;
    }
    final start = input.substring(0, 5);
    final end = input.substring(input.length - 2);
    final middle = '*' * (input.length - 7);
    return '$start$middle$end';
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
              
              // Step 1: Clear all data first.
              // Audit M5: the `login` key is no longer written, but legacy
              // installs may still have it — keep the delete for cleanup.
              try {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                await _secureStorage.delete(key: 'token');
                await _secureStorage.delete(key: 'user_id');
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
      final existingToken = await _secureStorage.read(key: 'token');
      final hasExistingToken = existingToken != null && existingToken.isNotEmpty;

      // App lock path: verify password against authenticated session, do NOT call /login.
      // Calling /login on same device can incorrectly trigger takeover OTP because active
      // tokens already exist for this account.
      if (widget.isAppLock && hasExistingToken) {
        setState(() {
          _isAuthenticating = true;
          _waitingForBackendValidation = false;
          _passwordError = null;
        });

        final verified = await _authRepository.verifySessionUnlockPassword(_password);
        if (!mounted) return;

        if (verified) {
          final securityCubit = context.read<SecurityCubit>();
          _isAuthenticating = false;
          _password = '';
          _pinController.clear();
          _passwordError = null;
          setState(() {});

          securityCubit.unlockApp();
          securityCubit.recordActivity();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.go('/home');
          });
        } else {
          setState(() {
            _isAuthenticating = false;
            _password = '';
            _pinController.clear();
            _passwordError = 'Incorrect PIN';
          });
        }
        return;
      }

      // Audit M5: no longer read the email/phone identifier from secure
      // storage. For idle-lock the resident AuthBloc state still has the
      // session login (in-memory only); for fresh-login it's the phone /
      // email passed in via route extras.
      String login = widget.phoneNumber;
      if (login.isEmpty && mounted) {
        final auth = context.read<AuthBloc>().state;
        if (auth is AuthAuthenticated) {
          login = auth.login;
        }
      }

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
      if (e is DioException && isDioTransportFailure(e)) {
        if (mounted) {
          setState(() {
            _isAuthenticating = false;
            _waitingForBackendValidation = false;
            _password = '';
            _pinController.clear();
          });
          // ignore: unawaited_futures
          context.read<SplashCubit>().initApp();
          context.go('/');
        }
        return;
      }
      final msg = _friendlyBackendError(e);
      setState(() {
        _isAuthenticating = false;
        _waitingForBackendValidation = false;
        _passwordError = msg;
      });
    }
  }

  void _restartSplashColdStart() {
    if (!mounted) return;
    context.read<SplashCubit>().initApp();
    context.go('/');
  }

  String _friendlyBackendError(Object error) {
    return error.toString().replaceFirst('Exception: ', '').trim();
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

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is AuthUnauthenticated || current is AuthInitial,
      listener: (context, state) {
        if (!mounted) {
          return;
        }
        if (_waitingForBackendValidation || _isAuthenticating) {
          setState(() {
            _waitingForBackendValidation = false;
            _isAuthenticating = false;
            _password = '';
            _pinController.clear();
          });
        }
      },
      child: BlocListener<SecurityCubit, SecurityState>(
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
          if (previous is AuthSessionTakeoverPending) {
            if (_lastProcessedError != current.error) {
              _lastProcessedError = current.error;
              return true;
            }
            return false;
          }
          return false;
        } else if (current is AuthSessionTakeoverPending) {
          if (_waitingForBackendValidation &&
              previous is AuthVerifyingCredentials &&
              _isAuthenticating) {
            return true;
          }
          return false;
        }
        return false;
      },
      listener: (context, state) {
        // Handle authentication responses
        if (state is AuthSessionTakeoverPending) {
          _lastProcessedError = null;
          if (mounted) {
            setState(() {
              _isAuthenticating = false;
              _waitingForBackendValidation = false;
              _password = '';
              _pinController.clear();
              _passwordError = null;
            });
            context.push('/session-takeover');
          }
          return;
        }
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
          if (shouldRedirectToSplashForAuthFailure(state.error)) {
            _waitingForBackendValidation = false;
            _isAuthenticating = false;
            _password = '';
            _pinController.clear();
            _passwordError = null;
            if (mounted) {
              setState(() {});
              _restartSplashColdStart();
            }
            return;
          }

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
            final authState = context.watch<AuthBloc>().state;
            // [LoginRequested] emits [AuthVerifyingCredentials], not [AuthAuthenticated].
            // Treat both as an active session so the PIN loader stays visible during the API call.
            final hasAuthSession = authState is AuthAuthenticated ||
                authState is AuthVerifyingCredentials;
            final shouldShowLoader = hasAuthSession &&
                (_waitingForBackendValidation ||
                    (_isAuthenticating &&
                        securityState == SecurityState.locked));
            
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
                              // App lock: avoid a circular "timer" look on the PIN screen.
                              if (widget.isAppLock) {
                                return Container(
                                  width: 80.w,
                                  height: 80.w,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey.shade200,
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    size: 40.sp,
                                    color: Colors.grey.shade600,
                                  ),
                                );
                              }
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

              // Masked email / phone — the in-memory copy only (audit M5:
              // never read this value from secure storage; see
              // [_getMaskedLogin] for the source priority).
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
                // Get the user's login (email or phone) for the forgot-password
                // pre-fill. Audit M5: never read it from secure storage —
                // use the in-memory user model or the route extras.
                String? login = _user?.login;
                if (login == null || login.isEmpty) {
                  login = widget.phoneNumber;
                }
                if ((login.isEmpty) && mounted) {
                  final auth = context.read<AuthBloc>().state;
                  if (auth is AuthAuthenticated) {
                    login = auth.login;
                  }
                }

                final Map<String, dynamic> extra = {};
                if (login != null && login.isNotEmpty) {
                  extra['preFilledContact'] = login;
                }

                if (!mounted) return;
                // ignore: unawaited_futures
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

