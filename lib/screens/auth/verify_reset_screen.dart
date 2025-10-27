import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/otp_input_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class VerifyResetScreen extends StatefulWidget {
  const VerifyResetScreen({
    super.key,
    required this.contact,
    this.isEmail = true,
  });

  final String contact;
  final bool isEmail;

  @override
  State<VerifyResetScreen> createState() => _VerifyResetScreenState();
}

class _VerifyResetScreenState extends State<VerifyResetScreen> {
  String _code = '';
  int _resendTimer = 34;
  Timer? _timer;

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
      // TODO: Verify code with backend
      // Navigate to reset password screen
      context.push('/reset-password');
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
                child: RichText(
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
              AppElevatedButton(
                title: 'Continue',
                onPressed: _code.length == 6 ? _verifyCode : null,
              ),

              vSpace(40),
            ],
          ),
        ),
      ),
    );
  }

}

