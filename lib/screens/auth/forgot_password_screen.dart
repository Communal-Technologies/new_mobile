import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/phone_input_field.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/core/utils/phone_login_format.dart';
import 'package:communal_mobile/data/models/region_model.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/data/repositories/regions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';

enum LoginType { phone, email }

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.preFilledContact,
  });

  final String? preFilledContact;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _phoneError;
  String? _emailError;
  LoginType _loginType = LoginType.phone;
  bool _isLoading = false;
  List<RegionModel> _regions = RegionModel.offlineFallback;
  bool _regionsLoading = true;
  PhoneNumber? _initialPhone;
  PhoneNumber? _phoneNumber;
  bool _phoneValid = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadRegions();
    if (!mounted) return;
    final pre = widget.preFilledContact;
    if (pre != null && pre.isNotEmpty) {
      if (pre.contains('@')) {
        setState(() {
          _loginType = LoginType.email;
          _emailController.text = pre;
        });
      } else {
        final isos = _regions.map((r) => r.countryIso).toList();
        final pn = await PhoneLoginFormat.phoneNumberForPrefill(pre, isos);
        if (!mounted) return;
        setState(() {
          _loginType = LoginType.phone;
          _initialPhone = pn;
        });
      }
    }
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
    _emailController.dispose();
    super.dispose();
  }

  void _toggleLoginType() {
    setState(() {
      _loginType = _loginType == LoginType.phone ? LoginType.email : LoginType.phone;
      _phoneError = null;
      _emailError = null;
    });
  }

  Future<void> _sendCode() async {
    setState(() {
      _phoneError = null;
      _emailError = null;
      _isLoading = true;
    });

    String contact;
    bool isEmail;

    if (_loginType == LoginType.phone) {
      if (_phoneNumber == null || !_phoneValid) {
        setState(() {
          _phoneError = 'Enter a valid phone number';
          _isLoading = false;
        });
        return;
      }

      contact = PhoneLoginFormat.apiLoginFromPhoneNumber(_phoneNumber!);
      isEmail = false;
    } else {
      if (_emailController.text.isEmpty) {
        setState(() {
          _emailError = 'Email is required';
          _isLoading = false;
        });
        return;
      }

      if (!_emailController.text.contains('@')) {
        setState(() {
          _emailError = 'Please enter a valid email address';
          _isLoading = false;
        });
        return;
      }

      contact = _emailController.text.trim();
      isEmail = true;
    }

    try {
      await getIt<AuthRepository>().requestPasswordReset(contact);
      if (!mounted) return;
      // Fire-and-forget — context.push returns a Future that resolves on
      // pop; we don't need that here.
      // ignore: unawaited_futures
      context.push('/verify-reset', extra: {
        'contact': contact,
        'isEmail': isEmail,
        'isForgotPassword': true,
      });
    } catch (e) {
      if (!mounted) return;
      final message = e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
      AppToast.error(message);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: _isLoading ? null : () => context.pop(),
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
                child: Text(
                  _loginType == LoginType.phone
                      ? 'Enter your phone number to reset your password'
                      : 'Enter your email address to reset your password',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),

              vSpace(32),

              // Phone or Email input
              if (_loginType == LoginType.phone)
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
                        initialValue: _initialPhone,
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
                      )
              else
                CustomTextField(
                  controller: _emailController,
                  hintText: 'Enter your email',
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                  onChanged: (_) {
                    if (_emailError != null) {
                      setState(() {
                        _emailError = null;
                      });
                    }
                  },
                ),

              vSpace(12),

              // Toggle link
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _toggleLoginType,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _loginType == LoginType.phone
                        ? 'Use email instead'
                        : 'Use phone number instead',
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

              vSpace(12),

              // Send code button
              AppElevatedButton(
                title: 'Send Code',
                onPressed: _isLoading ? null : _sendCode,
                isLoading: _isLoading,
              ),

              vSpace(24),
            ],
          ),
        ),
      ),
        ),
        if (_isLoading)
          Positioned.fill(
            child: const LoaderOverlay(),
          ),
      ],
    );
  }
}

