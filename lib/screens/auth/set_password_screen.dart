import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _passwordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateAndContinue() {
    setState(() {
      _passwordError = null;
      _confirmPasswordError = null;
    });

    // Validation
    if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordError = 'Password is required';
      });
      return;
    }

    if (_passwordController.text.length < 8) {
      setState(() {
        _passwordError = 'Password must be at least 8 characters';
      });
      return;
    }

    if (_confirmPasswordController.text.isEmpty) {
      setState(() {
        _confirmPasswordError = 'Please re-enter your password';
      });
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _confirmPasswordError = 'Passwords do not match';
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
                  'Set your sign in Password',
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
                  'Set a password to sign in, for account security.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ),

              vSpace(32),

              // Create Password
              CustomTextField(
                controller: _passwordController,
                labelText: 'Create your Password',
                hintText: 'Enter password',
                obscureText: _obscurePassword,
                errorText: _passwordError,
                keyboardType: TextInputType.visiblePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                onChanged: (_) {
                  if (_passwordError != null) {
                    setState(() {
                      _passwordError = null;
                    });
                  }
                },
              ),

              vSpace(24),

              // Re-enter Password
              CustomTextField(
                controller: _confirmPasswordController,
                labelText: 'Re-enter your Password',
                hintText: 'Re-enter password',
                obscureText: _obscureConfirmPassword,
                errorText: _confirmPasswordError,
                keyboardType: TextInputType.visiblePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
                onChanged: (_) {
                  if (_confirmPasswordError != null) {
                    setState(() {
                      _confirmPasswordError = null;
                    });
                  }
                },
              ),

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
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),

              vSpace(16),

              // PIN option
              InkWell(
                onTap: () {
                  context.pushReplacement('/set-pin');
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
                      '6-digit PIN (numbers)',
                      style: TextStyle(
                        fontSize: 16.sp,
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
                        fontSize: 11.sp,
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
                        fontSize: 11.sp,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    hSpace(8),
                    Text(
                      'Deposits insured by',
                      style: TextStyle(
                        fontSize: 11.sp,
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

