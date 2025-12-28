import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/otp_input_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';

class VerifyResetScreen extends StatefulWidget {
  const VerifyResetScreen({
    super.key,
    required this.contact,
    this.isEmail = true,
    this.isInitialSetup = false,
    this.isForgotPassword = false,
    this.userId,
  });

  final String contact;
  final bool isEmail;
  final bool isInitialSetup;
  final bool isForgotPassword;
  final String? userId;

  @override
  State<VerifyResetScreen> createState() => _VerifyResetScreenState();
}

class _VerifyResetScreenState extends State<VerifyResetScreen> {
  String _code = '';
  int _resendTimer = 34;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() {
          _resendTimer--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _resendCode() {
    setState(() {
      _resendTimer = 34;
    });
    _startTimer();
    // TODO: Implement actual resend logic
  }

  String get _maskedContact {
    if (widget.isEmail) {
      // Mask email
      final parts = widget.contact.split('@');
      if (parts.length == 2) {
        final username = parts[0];
        final domain = parts[1];
        if (username.length > 3) {
          final start = username.substring(0, 3);
          final end = username.substring(username.length - 2);
          return '$start****$end@$domain';
        }
      }
      return widget.contact;
    } else {
      // Mask phone
      if (widget.contact.length >= 11) {
        final prefix = widget.contact.substring(0, 7);
        final suffix = widget.contact.substring(widget.contact.length - 4);
        return '$prefix****$suffix';
      }
      return widget.contact;
    }
  }

  void _verifyCode() {
    if (_code.length == 6) {
      // Dismiss keyboard
      FocusScope.of(context).unfocus();
      
      setState(() {
        _isVerifying = true;
      });

      // For forgot password flow, accept dummy code "123456" and skip backend verification
      if (widget.isForgotPassword) {
        // Accept dummy code for now (since mail isn't implemented)
        if (_code == '123456') {
      // Navigate to reset password screen
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              context.push('/reset-password', extra: {
                'contact': widget.contact,
                'isEmail': widget.isEmail,
              });
            }
          });
        } else {
          setState(() {
            _isVerifying = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid code. Use 123456 for testing.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // Normal OTP verification for initial setup
        context.read<AuthBloc>().add(VerifyOtpRequested(
              contact: widget.contact,
              otp: _code,
              isEmail: widget.isEmail,
              isInitialSetup: widget.isInitialSetup,
              userId: widget.userId,
            ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              vSpace(20),

              // Logo
              Center(
                child: Image.asset(
                  Images.coloredLogo,
                  width: 180.w,
                ),
              ),

              vSpace(40),

              // Title
              Center(
                child: Text(
                  'Verify ${widget.isEmail ? 'Email' : 'Phone'}',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),

              vSpace(12),

              // Instruction
              Center(
                child: Column(
                  children: [
                    RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: widget.isEmail
                            ? 'Enter the code we sent to your email'
                            : 'Enter the code we sent to your phone on whatsapp',
                      ),
                      TextSpan(
                        text: '\n$_maskedContact',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                    ),
                    // Show dummy code hint for forgot password flow
                    if (widget.isForgotPassword) ...[
                      vSpace(12),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          'Use dummy code: 123456',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              vSpace(32),

              // OTP Input
              OtpInputField(
                length: 6,
                onChanged: (code) {
                  setState(() {
                    _code = code;
                  });
                },
              ),

              vSpace(16),

              // Resend code
              Center(
                child: _resendTimer > 0
                    ? Text(
                        'Resend code in ${_resendTimer}s',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey.shade600,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Didn\'t receive the code?',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          hSpace(4),
                          TextButton(
                            onPressed: _resendCode,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Resend',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
              ),

              vSpace(32),

              // Continue button
              BlocConsumer<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is VerifyOtpSuccess) {
                    setState(() {
                      _isVerifying = false;
                    });
                    // Navigate to reset password screen
                    context.push('/reset-password', extra: {
                      'userId': state.userId,
                      'contact': state.contact,
                      'isInitialSetup': widget.isInitialSetup,
                    });
                  } else if (state is AuthFailure) {
                    setState(() {
                      _isVerifying = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          state.error,
                          style: const TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                builder: (context, state) {
                  // Only show loading when user has clicked the button
                  // _isVerifying is set to true only when user clicks
                  final isLoading = _isVerifying;
                  return AppElevatedButton(
                title: 'Continue',
                    onPressed: (_code.length == 6 && !isLoading) ? _verifyCode : null,
                    isLoading: isLoading,
                  );
                },
              ),

              vSpace(40),
            ],
          ),
        ),
      ),
    );
  }

}

