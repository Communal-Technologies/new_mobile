import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/otp_input_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class SetPinScreen extends StatefulWidget {
  const SetPinScreen({super.key});

  @override
  State<SetPinScreen> createState() => _SetPinScreenState();
}

class _SetPinScreenState extends State<SetPinScreen> {
  String _pin = '';
  String _confirmPin = '';
  String? _pinError;

  void _validateAndContinue() {
    setState(() {
      _pinError = null;
    });

    if (_pin.isEmpty || _pin.length != 6) {
      setState(() {
        _pinError = 'Please enter a 6-digit PIN';
      });
      return;
    }

    if (_confirmPin.isEmpty || _confirmPin.length != 6) {
      setState(() {
        _pinError = 'Please re-enter your PIN';
      });
      return;
    }

    if (_pin != _confirmPin) {
      setState(() {
        _pinError = 'The first and second PIN do not match';
      });
      return;
    }

    // Navigate to success screen
    context.push('/account-success');
  }

  @override
  Widget build(BuildContext context) {
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
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
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
                  'Set your sign in PIN',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),

              vSpace(12),

              // Subtitle
              Center(
                child: Text(
                  'Set a 6-digit PIN to sign in, for account security.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ),

              vSpace(32),

              // Create PIN
              Text(
                'Create your PIN',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              vSpace(12),
              OtpInputField(
                length: 6,
                onChanged: (code) {
                  setState(() {
                    _pin = code;
                    if (_pinError != null) {
                      _pinError = null;
                    }
                  });
                },
              ),

              vSpace(24),

              // Re-enter PIN
              Text(
                'Re-enter your PIN',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              vSpace(12),
              OtpInputField(
                length: 6,
                onChanged: (code) {
                  setState(() {
                    _confirmPin = code;
                    if (_pinError != null) {
                      _pinError = null;
                    }
                  });
                },
              ),

              if (_pinError != null) ...[
                vSpace(8),
                Text(
                  _pinError!,
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 15.sp,
                  ),
                ),
              ],

              vSpace(32),

              // Continue button
              AppElevatedButton(
                title: 'Continue',
                onPressed: _validateAndContinue,
              ),

              vSpace(20),

              // Alternative
              Center(
                child: Text(
                  'Or sign in with',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),

              vSpace(16),

              // Password option
              InkWell(
                onTap: () {
                  context.pushReplacement('/set-password');
                },
                borderRadius: BorderRadius.circular(25.r),
                child: Container(
                  width: double.infinity,
                  height: 50.h,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(25.r),
                  ),
                  child: Center(
                    child: Text(
                      'Password (Alpha-numeric)',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),

              vSpace(40),
                    ],
                  ),
                ),
              ),

              // Footer - regulatory info (fixed at bottom)
              vSpace(16),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Licensed by CBN',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    hSpace(4),
                    Container(
                      width: 20.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          'CBN',
                          style: TextStyle(
                            fontSize: 6.sp,
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    hSpace(8),
                    Text(
                      '|',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    hSpace(8),
                    Text(
                      'Deposits insured by',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    hSpace(4),
                    Container(
                      width: 40.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Center(
                        child: Text(
                          'NDIC',
                          style: TextStyle(
                            fontSize: 8.sp,
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              vSpace(24),
            ],
          ),
        ),
      ),
    );
  }
}

