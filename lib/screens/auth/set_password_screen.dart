import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({
    super.key,
    this.phone,
    this.userId,
  });

  /// Carried through from the OTP-verify step in the self-signup chain.
  /// Null when the user lands here directly (we surface an inline error
  /// telling them to restart from the phone-verification screen).
  final String? phone;
  final String? userId;

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
  bool _submitting = false;

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

    // Mobile platform rule (mirrors AuthController::createPassword on
    // the backend): exactly 6 numeric digits, not all the same digit.
    // Web's 8+ alphanumeric rule does NOT apply on this platform — the
    // backend rejects it with 400. Validate up-front so the user gets
    // a clear message instead of the generic backend error.
    final pwd = _passwordController.text;
    if (pwd.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      return;
    }
    if (pwd.length != 6) {
      setState(() => _passwordError = 'Password must be exactly 6 digits');
      return;
    }
    if (!RegExp(r'^[0-9]{6}$').hasMatch(pwd)) {
      setState(() => _passwordError = 'Password must contain only numbers');
      return;
    }
    if (pwd.split('').every((c) => c == pwd[0])) {
      setState(() => _passwordError =
          'Password cannot be all the same digit. Use a mix of numbers.');
      return;
    }

    if (_confirmPasswordController.text.isEmpty) {
      setState(() => _confirmPasswordError = 'Please re-enter your password');
      return;
    }
    if (pwd != _confirmPasswordController.text) {
      setState(() => _confirmPasswordError = 'Passwords do not match');
      return;
    }

    final userId = widget.userId;
    if (userId == null || userId.isEmpty) {
      setState(() => _passwordError =
          'Please restart signup from the phone-verification screen.');
      return;
    }

    setState(() => _submitting = true);
    context.read<AuthBloc>().add(
          CreatePasswordRequested(
            userId: userId,
            password: pwd,
            confirmPassword: _confirmPasswordController.text,
            contact: widget.phone,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated && _submitting) {
          context.go('/account-success');
        } else if (state is AuthFailure && _submitting) {
          setState(() {
            _submitting = false;
            _passwordError = state.error;
          });
        }
      },
      child: _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: _submitting ? null : () => context.pop(),
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
                    fontSize: 15.sp,
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
                title: _submitting ? 'Creating account...' : 'Continue',
                onPressed: _submitting ? null : _validateAndContinue,
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

              // PIN option — same userId / phone forwarded so /set-pin
              // can finish the account creation if the user prefers a
              // PIN to a numeric password.
              InkWell(
                onTap: _submitting
                    ? null
                    : () {
                        context.pushReplacement(
                          '/set-pin',
                          extra: {
                            'phone': widget.phone,
                            'userId': widget.userId,
                          },
                        );
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

