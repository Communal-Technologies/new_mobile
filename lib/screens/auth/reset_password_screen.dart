import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/numeric_keypad.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/dio_transport_user_message.dart';
import 'package:communal_mobile/cubits/splash/splash_cubit.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.userId,
    this.contact,
    this.pin,
    this.isInitialSetup = false,
  });

  final String? userId;
  final String? contact;
  /// 6-digit code from email/SMS (required when resetting an existing password).
  final String? pin;
  final bool isInitialSetup;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  String _newPassword = '';
  String _confirmPassword = '';
  String? _passwordError;
  bool _isSubmitting = false;
  bool _isConfirming = false; // Track if we're on the confirmation step
  bool _hasSubmitted = false; // Prevent multiple submissions
  bool _isPasswordVisible = false; // Toggle password visibility

  void _restartSplashColdStart() {
    if (!mounted) return;
    context.read<SplashCubit>().initApp();
    context.go('/');
  }

  /// Mask contact (email or phone) for display
  String _maskContact(String contact) {
    if (contact.isEmpty) return '****';
    
    // Check if it's an email
    if (contact.contains('@')) {
      final parts = contact.split('@');
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
    if (contact.length <= 7) {
      return '*' * contact.length;
    }
    final start = contact.substring(0, 3);
    final end = contact.substring(contact.length - 4);
    final middle = '*' * (contact.length - 7);
    return '$start$middle$end';
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onNumberTap(String number) {
    if (!_isConfirming) {
      // First password entry
      if (_newPassword.length < 6) {
        setState(() {
          _newPassword += number;
          _passwordError = null;
        });

        // Auto-submit when 6 digits are entered
        if (_newPassword.length == 6) {
          // Move to confirmation step
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                _isConfirming = true;
              });
            }
          });
        }
      }
    } else {
      // Confirmation password entry
      if (_confirmPassword.length < 6) {
        setState(() {
          _confirmPassword += number;
          _passwordError = null;
        });

        // Auto-submit when 6 digits are entered
        if (_confirmPassword.length == 6 && !_hasSubmitted) {
          _validateAndReset();
        }
      }
    }
  }

  void _onBackspace() {
    if (!_isConfirming) {
      if (_newPassword.isNotEmpty) {
        setState(() {
          _newPassword = _newPassword.substring(0, _newPassword.length - 1);
          _passwordError = null;
        });
      }
    } else {
      if (_confirmPassword.isNotEmpty) {
        setState(() {
          _confirmPassword = _confirmPassword.substring(0, _confirmPassword.length - 1);
          _passwordError = null;
        });
      }
    }
  }

  void _validateAndReset() {
    // Prevent multiple submissions
    if (_hasSubmitted || _isSubmitting) {
      return;
    }

    // Dismiss keyboard
    FocusScope.of(context).unfocus();
    
    setState(() {
      _passwordError = null;
    });

    // Validation
    if (_newPassword.isEmpty || _newPassword.length != 6) {
      setState(() {
        _passwordError = 'Please enter a 6-digit password';
        _isConfirming = false;
        _confirmPassword = '';
      });
      return;
    }

    // Check if password is all the same character (brute force prevention)
    final firstChar = _newPassword[0];
    if (_newPassword.split('').every((char) => char == firstChar)) {
      setState(() {
        _passwordError = 'Password cannot be all the same digit. Please use a mix of different numbers.';
        _isConfirming = false;
        _confirmPassword = '';
      });
      return;
    }

    if (_confirmPassword.isEmpty || _confirmPassword.length != 6) {
      setState(() {
        _passwordError = 'Please re-enter your password';
      });
      return;
    }

    if (_newPassword != _confirmPassword) {
      setState(() {
        _passwordError = 'Passwords do not match';
        _isConfirming = false;
        _confirmPassword = '';
      });
      return;
    }

    // If this is initial setup, create password and auto-login
    if (widget.isInitialSetup && widget.userId != null) {
      setState(() {
        _isSubmitting = true;
        _hasSubmitted = true; // Mark as submitted to prevent duplicates
      });
      context.read<AuthBloc>().add(CreatePasswordRequested(
            userId: widget.userId!,
            password: _newPassword,
            confirmPassword: _confirmPassword,
            contact: widget.contact,
          ));
    } else {
      // Regular password reset flow - call API to reset password
      if (widget.contact == null || widget.contact!.isEmpty) {
        setState(() {
          _passwordError = 'Contact information is required';
          _isSubmitting = false;
          _hasSubmitted = false;
        });
        return;
      }
      if (widget.pin == null || widget.pin!.length != 6) {
        setState(() {
          _passwordError = 'Verification code is required. Go back and verify your code.';
          _isSubmitting = false;
          _hasSubmitted = false;
        });
        return;
      }

      setState(() {
        _isSubmitting = true;
        _hasSubmitted = true; // Mark as submitted to prevent duplicates
      });
      
      // Dispatch reset password event
      context.read<AuthBloc>().add(ResetPasswordRequested(
            login: widget.contact!,
            newPassword: _newPassword,
            pin: widget.pin!,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is CreatePasswordSuccess) {
          setState(() {
            _isSubmitting = false;
          });
          if (state.token != null) {
            // Token was returned, user is already logged in
            context.go('/home');
          } else {
            // No token, need to login
            if (widget.contact != null) {
              // Auto-login after password creation
              context.read<AuthBloc>().add(LoginRequested(
                    login: widget.contact!,
                    password: _newPassword,
                  ));
            } else {
              // Navigate to login
              context.go('/login');
            }
          }
        } else if (state is AuthSessionTakeoverPending) {
          setState(() {
            _isSubmitting = false;
          });
          context.push('/session-takeover');
        } else if (state is ResetPasswordSuccess) {
          // Password reset successful, user should be authenticated automatically
          setState(() {
            _isSubmitting = false;
          });
          // Wait a bit for AuthAuthenticated state to be emitted
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              context.go('/home');
            }
          });
        } else if (state is AuthAuthenticated) {
          // User is authenticated, navigate to home
          context.go('/home');
        } else if (state is AuthFailure) {
          if (shouldRedirectToSplashForAuthFailure(state.error)) {
            setState(() {
              _isSubmitting = false;
              _hasSubmitted = false;
              _passwordError = null;
            });
            _restartSplashColdStart();
            return;
          }
          setState(() {
            _isSubmitting = false;
            _hasSubmitted = false; // Allow retry on error
            _passwordError = state.error; // Show error in UI
          });
          // Show snackbar only once
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.error,
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      },
      builder: (context, state) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Scaffold(
              backgroundColor: Theme.of(context).cardColor,
              appBar: AppBar(
                backgroundColor: Theme.of(context).cardColor,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _isSubmitting ? null : () => context.pop(),
                ),
              ),
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    children: [
                      vSpace(10),

                      // Logo
                      Center(
                        child: Image.asset(
                          Theme.of(context).brightness == Brightness.dark ? Images.whiteLogo : Images.coloredLogo,
                          width: 130.w,
                        ),
                      ),

                      vSpace(24),

                      // Profile picture placeholder
                      Center(
                        child: Container(
                          width: 80.w,
                          height: 80.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).dividerColor,
                          ),
                          child: Icon(
                            Icons.person,
                            size: 40.sp,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),

                      vSpace(16),

                      // Title
                      Center(
                        child: Text(
                          _isConfirming ? 'Confirm PIN' : 'Set New PIN',
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ),

                      vSpace(6),

                      // Instructions
                      Center(
                        child: Text(
                          _isConfirming
                              ? 'Re-enter your 6-digit PIN to confirm'
                              : widget.contact != null 
                                  ? _maskContact(widget.contact!)
                                  : 'Enter a 6-digit numeric PIN',
                          style: TextStyle(
                            fontSize: 17.sp,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      vSpace(32),

                      // Password input display (PIN-style) - Matching welcome back screen
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(6, (index) {
                          final currentPassword = _isConfirming ? _confirmPassword : _newPassword;
                          final hasValue = index < currentPassword.length;
                          final hasError = _passwordError != null;
                          final theme = Theme.of(context);
                          return Flexible(
                            child: GestureDetector(
                              onTap: () {
                                // Toggle visibility when tapping on a circle
                                if (currentPassword.isNotEmpty) {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                }
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
                                                currentPassword[index],
                                                style: TextStyle(
                                                  fontSize: 19.sp,
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
                            fontSize: 17.sp,
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      vSpace(12),

                      vSpace(24),

                      // Numeric keypad
                      NumericKeypad(
                        onNumberTap: _onNumberTap,
                        onBackspace: _onBackspace,
                      ),

                      vSpace(20),
                    ],
                  ),
                ),
              ),
            ),
            if (_isSubmitting)
              Positioned.fill(
                child: const LoaderOverlay(),
              ),
          ],
        );
      },
    );
  }
}

