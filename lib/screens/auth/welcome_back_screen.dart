import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/numeric_keypad.dart';
import 'package:communal_mobile/core/widgets/space.dart';
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

  @override
  void initState() {
    super.initState();
    _currentMethod = widget.method;
    _authRepository = getIt<AuthRepository>();
    _loadUserInfo();
    _checkBiometricAvailability();
  }

  Future<void> _loadUserInfo() async {
    try {
      final token = await _secureStorage.read(key: 'token');
      if (token != null) {
        final user = await _authRepository.getUserInfo(token);
        if (mounted && user != null) {
          setState(() {
            _user = user;
          });
          // Re-check biometric availability after user is loaded
          // to see if user has security pin set
          _checkBiometricAvailability();
        }
      }
    } catch (e) {
      // Failed to load user info, continue without it
      print('Failed to load user info: $e');
    }
  }

  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await BiometricService.isBiometricAvailable();
    final biometricName = await BiometricService.getBiometricName();
    
    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable;
        _biometricName = biometricName;
      });
      
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
              // Clear all data and logout (onboarding flag is preserved in secure storage)
              context.read<AuthBloc>().add(LogoutRequested());
              
              // Clear SharedPreferences (onboarding flag is in secure storage, so it's safe)
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              
              // Navigate to welcome screen
              if (mounted) {
                context.go('/welcome');
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

    // Get stored login info and authenticate with password
    // For now, dispatch login event - you'll need to get the login from storage
    // Verify password and unlock/navigate
    if (widget.isAppLock) {
      // For app lock, verify password hash
      final storedHash = await _secureStorage.read(key: 'password_hash');
      
      if (storedHash == null || storedHash.isEmpty) {
        // No password hash stored, need to verify with backend
        // Get stored login and verify with backend
        final storedLogin = await _secureStorage.read(key: 'login');
        if (storedLogin != null && storedLogin.isNotEmpty) {
          // Verify with backend
          context.read<AuthBloc>().add(LoginRequested(
            login: storedLogin,
            password: _password,
          ));
          // BlocListener will handle the response
          return;
        } else {
          // No login stored, show error
          setState(() {
            _isAuthenticating = false;
            _passwordError = 'Unable to verify password. Please log in again.';
          });
          return;
        }
      }
      
      final passwordHash = sha256.convert(utf8.encode(_password)).toString();
      
      if (storedHash == passwordHash) {
        // Password correct, unlock app
        context.read<SecurityCubit>().unlockApp();
        setState(() {
          _isAuthenticating = false;
          _password = '';
          _pinController.clear();
        });
      } else {
        // Show error - incorrect password
        _handlingErrorLocally = true;
        setState(() {
          _isAuthenticating = false;
          _password = ''; // Clear password on incorrect entry
          _pinController.clear(); // Clear controller
          _passwordError = 'Incorrect password';
        });
        // Reset flag after a delay
        Future.delayed(const Duration(milliseconds: 500), () {
          _handlingErrorLocally = false;
        });
      }
    } else {
      // For login flow, verify password with backend
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
        
        // Dispatch login event to verify password
        // BlocListener will handle the response (success or failure)
        context.read<AuthBloc>().add(LoginRequested(
          login: login,
          password: _password,
        ));
      } catch (e) {
        setState(() {
          _isAuthenticating = false;
          _passwordError = 'Error: ${e.toString()}';
        });
      }
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

    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        // Only listen to AuthAuthenticated or AuthFailure states
        // Prevent duplicate processing by checking if we've already handled this error
        if (current is AuthAuthenticated) {
          _lastProcessedError = null; // Clear error tracking on success
          return true;
        } else if (current is AuthFailure) {
          // Only process if this is a different error message
          if (_lastProcessedError != current.error) {
            _lastProcessedError = current.error;
            return true;
          }
          return false; // Already processed this error
        }
        return false;
      },
      listener: (context, state) {
        // Handle authentication responses
        if (state is AuthAuthenticated) {
          // Authentication successful
          setState(() {
            _isAuthenticating = false;
            _password = '';
            _pinController.clear();
            _passwordError = null; // Clear any errors
          });
          
          if (widget.isAppLock) {
            // Unlock the app
            context.read<SecurityCubit>().unlockApp();
          } else {
            // Navigate to home (login flow)
            context.go('/home');
          }
        } else if (state is AuthFailure) {
          // Authentication failed, show error inline (no snackbar)
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
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for light background
        statusBarBrightness: Brightness.light, // Light status bar for iOS
      ),
      child: Scaffold(
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
                
                print('🔵 FORGOT PASSWORD - storedLogin: $storedLogin');
                print('🔵 FORGOT PASSWORD - _user?.login: ${_user?.login}');
                print('🔵 FORGOT PASSWORD - widget.phoneNumber: ${widget.phoneNumber}');
                print('🔵 FORGOT PASSWORD - final login: $login');
                
                // Navigate with login if available
                final Map<String, dynamic> extra = {};
                if (login.isNotEmpty) {
                  extra['preFilledContact'] = login;
                }
                
                print('🔵 FORGOT PASSWORD - Navigating with extra: $extra');
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

