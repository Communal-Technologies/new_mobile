import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailOrPhoneController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    super.dispose();
  }

  void _sendCode() {
    setState(() {
      _error = null;
    });

    if (_emailOrPhoneController.text.isEmpty) {
      setState(() {
        _error = 'Email or phone number is required';
      });
      return;
    }

    // Determine if email or phone
    final isEmail = _emailOrPhoneController.text.contains('@');

    // Navigate to verification
    context.push('/verify-reset', extra: {
      'contact': _emailOrPhoneController.text,
      'isEmail': isEmail,
    });
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

              vSpace(60),

              // Title
              Center(
                child: Text(
                  'Forgot Password?',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                ),
              ),

              vSpace(16),

              // Instructions
              Center(
                child: Column(
                  children: [
                    Text(
                      'Enter your email address or phone number',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'to reset your password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              vSpace(40),

              // Email or phone input
              CustomTextField(
                controller: _emailOrPhoneController,
                hintText: 'Email address or Phone',
                errorText: _error,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) {
                  if (_error != null) {
                    setState(() {
                      _error = null;
                    });
                  }
                },
              ),

              vSpace(32),

              // Send code button
              AppElevatedButton(
                title: 'Send Code',
                onPressed: _sendCode,
              ),

              vSpace(24),
            ],
          ),
        ),
      ),
    );
  }
}

