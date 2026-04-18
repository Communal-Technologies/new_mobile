import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/phone_input_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/core/utils/phone_login_format.dart';
import 'package:communal_mobile/data/models/region_model.dart';
import 'package:communal_mobile/data/repositories/regions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _phoneController = TextEditingController();
  bool _agreedToTerms = false;
  String? _phoneError;
  List<RegionModel> _regions = RegionModel.offlineFallback;
  bool _regionsLoading = true;
  PhoneNumber? _phoneNumber;
  bool _phoneValid = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    try {
      final list = await getIt<RegionsRepository>().fetchRegions();
      if (!mounted) return;
      setState(() {
        _regions = list.isNotEmpty ? list : RegionModel.offlineFallback;
        _regionsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _regions = RegionModel.offlineFallback;
        _regionsLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _validateAndContinue() {
    setState(() {
      _phoneError = null;
    });

    // Validation
    if (_phoneNumber == null || !_phoneValid) {
      setState(() {
        _phoneError = 'Enter a valid phone number';
      });
      return;
    }

    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please agree to Terms & Conditions',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Navigate to OTP verification
    context.push('/verify-phone', extra: {
      'phone': PhoneLoginFormat.apiLoginFromPhoneNumber(_phoneNumber!),
      'method': 'sms',
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
                  'Create your Account',
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
                  'Enter your phone number to get started',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),

              vSpace(32),

              // Phone input
              _regionsLoading
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.h),
                      child: Center(
                        child: SizedBox(
                          width: 28.w,
                          height: 28.w,
                          child: const CircularProgressIndicator(),
                        ),
                      ),
                    )
                  : PhoneInputField(
                      controller: _phoneController,
                      regions: _regions,
                      errorText: _phoneError,
                      onChanged: () {
                        if (_phoneError != null) {
                          setState(() {
                            _phoneError = null;
                          });
                        }
                      },
                      onPhoneNumberChanged: (phone, valid) {
                        setState(() {
                          _phoneNumber = phone;
                          _phoneValid = valid;
                        });
                      },
                    ),

              vSpace(24),

              // Sign up button
              AppElevatedButton(
                title: 'Sign up',
                onPressed: _validateAndContinue,
              ),

              vSpace(20),

              // Terms checkbox
              GestureDetector(
                onTap: () {
                  setState(() {
                    _agreedToTerms = !_agreedToTerms;
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child: Checkbox(
                        value: _agreedToTerms,
                        onChanged: (value) {
                          setState(() {
                            _agreedToTerms = value ?? false;
                          });
                        },
                        activeColor: Theme.of(context).primaryColor,
                        checkColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                      ),
                    ),
                    hSpace(12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.black87,
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(
                              text: 'I have read, understood, and agreed to the ',
                            ),
                            TextSpan(
                              text: 'Terms & Conditions',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  // TODO: Navigate to Terms
                                },
                            ),
                            const TextSpan(text: ', and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  // TODO: Navigate to Privacy
                                },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              vSpace(200),

              // Already have account
              Center(
                child: Column(
                  children: [
                    Text(
                      'Already have a Communal account?',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    vSpace(12),
                    AppSecondaryButton(
                      title: 'Sign in',
                      isDark: false,
                      onPressed: () {
                        context.push('/login');
                      },
                    ),
                  ],
                ),
              ),

              vSpace(24),
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
                    // CBN Logo placeholder
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
                    // NDIC Logo placeholder
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

