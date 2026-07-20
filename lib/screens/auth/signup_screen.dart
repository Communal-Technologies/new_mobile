import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/constants.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/utils/app_launcher.dart';
import 'package:communal_mobile/core/widgets/phone_input_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/core/utils/phone_login_format.dart';
import 'package:communal_mobile/data/models/region_model.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
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
  // When the backend reports an existing account for this number, surface
  // the prompt with a direct "Sign in" call-to-action instead of pushing
  // the user forward into the OTP step.
  bool _accountAlreadyExists = false;
  bool _submitting = false;
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

  Future<void> _validateAndContinue() async {
    if (_submitting) return;

    setState(() {
      _phoneError = null;
      _accountAlreadyExists = false;
    });

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

    final apiPhone = PhoneLoginFormat.apiLoginFromPhoneNumber(_phoneNumber!);

    setState(() => _submitting = true);
    String? userId;
    try {
      // Issuing the OTP from here does double duty: backend creates the
      // User row + sends the code AND surfaces the account-exists case
      // (HTTP 409, error_code: account_exists) so we can stop the user
      // here instead of letting them discover it on the OTP screen.
      userId = await getIt<AuthRepository>().requestOtpForSignup(apiPhone);
    } on AccountAlreadyExistsException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _accountAlreadyExists = true;
        _phoneError = e.message;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _phoneError = e.toString().replaceFirst('Exception: ', '');
      });
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (userId == null || userId.isEmpty) {
      setState(() {
        _phoneError = 'Could not start your signup. Please try again.';
      });
      return;
    }

    unawaited(context.push('/verify-phone', extra: {
      'phone': apiPhone,
      'method': 'sms',
      'userId': userId,
    }));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
                  Theme.of(context).brightness == Brightness.dark ? Images.whiteLogo : Images.coloredLogo,
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
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),

              vSpace(12),

              // Subtitle
              Center(
                child: Text(
                  'Enter your phone number to get started',
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                        if (_phoneError != null || _accountAlreadyExists) {
                          setState(() {
                            _phoneError = null;
                            _accountAlreadyExists = false;
                          });
                        }
                      },
                      onPhoneNumberChanged: (phone, valid) {
                        setState(() {
                          _phoneNumber = phone;
                          _phoneValid = valid;
                          if (_accountAlreadyExists) {
                            _accountAlreadyExists = false;
                            _phoneError = null;
                          }
                        });
                      },
                    ),

              vSpace(24),

              // Account-exists CTA replaces the Sign Up button when the
              // backend has already told us this contact has an account.
              // The user can still type a different number to retry —
              // we clear the flag on input change above.
              if (_accountAlreadyExists)
                AppElevatedButton(
                  title: 'Sign in instead',
                  onPressed: () => context.push('/login', extra: {
                    if (_phoneNumber != null) 'phoneNumber': _phoneNumber,
                  }),
                )
              else
                AppElevatedButton(
                  title: _submitting ? 'Please wait...' : 'Sign up',
                  onPressed: _submitting ? null : _validateAndContinue,
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
                            fontSize: 17.sp,
                            color: Theme.of(context).colorScheme.onSurface,
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
                                ..onTap = () => launchAppUrl(
                                      AppConstants.termsOfServiceUrl,
                                    ),
                            ),
                            const TextSpan(text: ', and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () => launchAppUrl(
                                      AppConstants.privacyPolicyUrl,
                                    ),
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
                        fontSize: 17.sp,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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

              // Footer - regulatory info (CBN / NDIC) — hidden for now per design.
              // Restore the Row below if/when the licensing copy returns.
              // vSpace(16),
              // Center(
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.center,
              //     children: [
              //       Text('Licensed by CBN', style: TextStyle(fontSize: 16.sp,
              //         color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              //       hSpace(4),
              //       Container(width: 20.w, height: 20.w,
              //         decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle),
              //         child: Center(child: Text('CBN',
              //           style: TextStyle(fontSize: 6.sp, color: Colors.green.shade800, fontWeight: FontWeight.bold)))),
              //       hSpace(8),
              //       Text('|', style: TextStyle(fontSize: 16.sp,
              //         color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
              //       hSpace(8),
              //       Text('Deposits insured by', style: TextStyle(fontSize: 16.sp,
              //         color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              //       hSpace(4),
              //       Container(width: 40.w, height: 20.w,
              //         decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4.r)),
              //         child: Center(child: Text('NDIC',
              //           style: TextStyle(fontSize: 8.sp, color: Colors.blue.shade800, fontWeight: FontWeight.bold)))),
              //     ],
              //   ),
              // ),
              vSpace(24),
            ],
          ),
        ),
      ),
    );
  }
}

