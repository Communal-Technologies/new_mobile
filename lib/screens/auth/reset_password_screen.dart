import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _newPasswordError;
  String? _confirmPasswordError;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validateAndReset() {
    setState(() {
      _newPasswordError = null;
      _confirmPasswordError = null;
    });

    // Validation
    if (_newPasswordController.text.isEmpty) {
      setState(() {
        _newPasswordError = 'Password is required';
      });
      return;
    }

    if (_newPasswordController.text.length < 8) {
      setState(() {
        _newPasswordError = 'Password must be at least 8 characters';
      });
      return;
    }

    // Check for letters and numbers
    final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(_newPasswordController.text);
    final hasNumbers = RegExp(r'[0-9]').hasMatch(_newPasswordController.text);

    if (!hasLetters || !hasNumbers) {
      setState(() {
        _newPasswordError = 'Password must contain both letters and numbers';
      });
      return;
    }

    if (_confirmPasswordController.text.isEmpty) {
      setState(() {
        _confirmPasswordError = 'Please confirm your password';
      });
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() {
        _confirmPasswordError = 'Passwords do not match';
      });
      return;
    }

    // Navigate to success screen
    context.push('/password-reset-success');
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

              vSpace(40),

              // Title
              Center(
                child: Text(
                  'Set New Password',
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
                child: Text(
                  'Your password must be at least 8 characters long and contain both letters and numbers.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ),

              vSpace(40),

              // New Password
              CustomTextField(
                controller: _newPasswordController,
                hintText: 'New Password',
                obscureText: _obscureNewPassword,
                errorText: _newPasswordError,
                keyboardType: TextInputType.visiblePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNewPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureNewPassword = !_obscureNewPassword;
                    });
                  },
                ),
                onChanged: (_) {
                  if (_newPasswordError != null) {
                    setState(() {
                      _newPasswordError = null;
                    });
                  }
                },
              ),

              vSpace(24),

              // Confirm Password
              CustomTextField(
                controller: _confirmPasswordController,
                hintText: 'Confirm New Password',
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

              vSpace(40),

              // Reset password button
              AppElevatedButton(
                title: 'Reset Password',
                onPressed: _validateAndReset,
              ),

              vSpace(24),
            ],
          ),
        ),
      ),
    );
  }
}

