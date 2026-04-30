import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/phone_input_field.dart';
import 'package:communal_mobile/core/widgets/custom_text_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/core/utils/phone_login_format.dart';
import 'package:communal_mobile/data/models/region_model.dart';
import 'package:communal_mobile/data/repositories/regions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/dio_transport_user_message.dart';
import 'package:communal_mobile/cubits/splash/splash_cubit.dart';

enum LoginType { phone, email }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.initialPhone});

  /// Pre-fills the phone field. Currently used by the signup screen's
  /// "Sign in instead" CTA (when the backend already had an account for
  /// the entered number) so the user doesn't retype.
  final PhoneNumber? initialPhone;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  String? _phoneError;
  String? _emailError;
  LoginType _loginType = LoginType.phone;
  bool _isLoading = false;
  List<RegionModel> _regions = RegionModel.offlineFallback;
  bool _regionsLoading = true;
  PhoneNumber? _phoneNumber;
  bool _phoneValid = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPhone != null) {
      _phoneNumber = widget.initialPhone;
      // Seed the visible text. PhoneInputField will reconcile with the
      // structured value on first onPhoneNumberChanged callback.
      _phoneController.text = widget.initialPhone?.phoneNumber ?? '';
    }
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

  void _validateAndSignIn() {
    setState(() {
      _phoneError = null;
      _emailError = null;
    });

    if (_loginType == LoginType.phone) {
      if (_phoneNumber == null || !_phoneValid) {
        setState(() {
          _phoneError = 'Enter a valid phone number';
        });
        return;
      }

      _checkLoginAndProceed(
        PhoneLoginFormat.apiLoginFromPhoneNumber(_phoneNumber!),
      );
    } else {
      if (_emailController.text.isEmpty) {
        setState(() {
          _emailError = 'Email is required';
        });
        return;
      }

      if (!_emailController.text.contains('@')) {
        setState(() {
          _emailError = 'Please enter a valid email address';
        });
        return;
      }

      _checkLoginAndProceed(_emailController.text);
    }
  }

  void _checkLoginAndProceed(String login) {
    setState(() {
      _isLoading = true;
    });

    // Dispatch event to check login
    context.read<AuthBloc>().add(CheckLoginRequested(login: login));
  }

  void _restartSplashColdStart() {
    if (!mounted) return;
    context.read<SplashCubit>().initApp();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
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
                  'Sign in to your Account',
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
                  _loginType == LoginType.phone
                      ? 'Enter your phone number to get started'
                      : 'Enter your email to get started',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                        initialValue: widget.initialPhone,
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

              // Sign in button
              BlocConsumer<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is AuthUnauthenticated || state is AuthInitial) {
                    if (_isLoading) {
                      setState(() => _isLoading = false);
                    }
                    return;
                  }
                  if (state is CheckLoginSuccess) {
                    setState(() {
                      _isLoading = false;
                    });
                    
                    if (state.hasPassword) {
                      // User has password, navigate to welcome back screen
                      final login = _loginType == LoginType.phone
                          ? PhoneLoginFormat.apiLoginFromPhoneNumber(
                              _phoneNumber!,
                            )
                          : _emailController.text;
                      context.push('/welcome-back', extra: {
                        'phone': login,
                        'isEmail': _loginType == LoginType.email,
                      });
                    } else {
                      // User doesn't have password — backend sends OTP on login-checker; go verify.
                      final login = _loginType == LoginType.phone
                          ? PhoneLoginFormat.apiLoginFromPhoneNumber(
                              _phoneNumber!,
                            )
                          : _emailController.text;
                      final msg = state.otpDeliveryMessage;
                      if (msg != null && msg.isNotEmpty) {
                        AppToast.error(msg);
                      }
                      context.push('/verify-reset', extra: {
                        'contact': login,
                        'isEmail': _loginType == LoginType.email,
                        'isInitialSetup': true,
                        'userId': state.userId,
                        'skipInitialOtpRequest': state.otpSent == true,
                      });
                    }
                  } else if (state is AuthFailure) {
                    if (shouldRedirectToSplashForAuthFailure(state.error)) {
                      if (_isLoading) {
                        setState(() => _isLoading = false);
                      }
                      _restartSplashColdStart();
                      return;
                    }
                    setState(() {
                      _isLoading = false;
                      // Show error message below the input field
                      if (_loginType == LoginType.phone) {
                        _phoneError = state.error;
                      } else {
                        _emailError = state.error;
                      }
                    });
                  }
                },
                builder: (context, state) {
                  return AppElevatedButton(
                    title: 'Sign in',
                    onPressed: _isLoading ? null : _validateAndSignIn,
                    isLoading: _isLoading,
                  );
                },
              ),

              vSpace(200),

              // Don't have account
              Center(
                child: Column(
                  children: [
                    Text(
                      'Don\'t have a Communal account?',
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    vSpace(12),
                    AppSecondaryButton(
                      title: 'Sign up',
                      isDark: false,
                      onPressed: () {
                        context.push('/signup');
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
              //       Text('Licensed by CBN', style: TextStyle(fontSize: 14.sp,
              //         color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              //       hSpace(4),
              //       Container(width: 20.w, height: 20.w,
              //         decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle),
              //         child: Center(child: Text('CBN',
              //           style: TextStyle(fontSize: 6.sp, color: Colors.green.shade800, fontWeight: FontWeight.bold)))),
              //       hSpace(8),
              //       Text('|', style: TextStyle(fontSize: 14.sp,
              //         color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4))),
              //       hSpace(8),
              //       Text('Deposits insured by', style: TextStyle(fontSize: 14.sp,
              //         color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              //       hSpace(4),
              //       Container(width: 40.w, height: 20.w,
              //         decoration: BoxDecoration(color: Colors.blue.shade100, borderRadius: BorderRadius.circular(4.r)),
              //         child: Center(child: Text('NDIC',
              //           style: TextStyle(fontSize: 8.sp, color: Colors.blue.shade800, fontWeight: FontWeight.bold)))),
              //     ],
              //   ),
              // ),
              // vSpace(24),
            ],
          ),
        ),
      ),
    );
  }
}

