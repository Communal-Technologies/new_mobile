import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/constants.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/services/otp_session_storage.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/otp_input_field.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/dio_transport_user_message.dart';
import 'package:communal_mobile/cubits/splash/splash_cubit.dart';
import 'package:dio/dio.dart';

class VerifyResetScreen extends StatefulWidget {
  const VerifyResetScreen({
    super.key,
    required this.contact,
    this.isEmail = true,
    this.isInitialSetup = false,
    this.isForgotPassword = false,
    this.userId,
    /// When true, login-checker already sent the OTP — do not call `/otp/send` on open.
    this.skipInitialOtpRequest = false,
  });

  final String contact;
  final bool isEmail;
  final bool isInitialSetup;
  final bool isForgotPassword;
  final String? userId;
  final bool skipInitialOtpRequest;

  @override
  State<VerifyResetScreen> createState() => _VerifyResetScreenState();
}

class _VerifyResetScreenState extends State<VerifyResetScreen> {
  // Audit M25: single source of truth for the OTP length lives in
  // [AppConstants.otpLength].
  static int get _otpLength => AppConstants.otpLength;
  static int get _resendWindow => AppConstants.otpResendWindowSeconds;

  final OtpSessionStorage _sessionStorage = OtpSessionStorage();

  /// Bumps to rebuild [OtpInputField] and clear digits after a failed attempt.
  int _otpFieldKey = 0;

  String _code = '';
  int _resendTimer = _resendWindow;
  Timer? _timer;
  Timer? _deliveryPollTimer;
  int _deliveryPollAttempts = 0;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _deliveryInfo;

  /// Which persisted slot this screen instance reads/writes. Forgot-password,
  /// initial-setup and plain verification each get their own slot so an
  /// abandoned flow never leaks its countdown into another.
  OtpFlow get _flow {
    if (widget.isForgotPassword) return OtpFlow.passwordReset;
    if (widget.isInitialSetup) return OtpFlow.initialSetup;
    return OtpFlow.verification;
  }

  void _restartSplashColdStart() {
    if (!mounted) return;
    context.read<SplashCubit>().initApp();
    context.go('/');
  }

  @override
  void initState() {
    super.initState();
    _restoreOrStart();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _deliveryPollTimer?.cancel();
    super.dispose();
  }

  /// Resumes the countdown from a persisted session for this exact
  /// contact + flow if one exists (app was closed and reopened mid-flow),
  /// otherwise falls back to the normal fresh-screen behavior.
  ///
  /// - Session found, still within the resend window -> resume the timer
  ///   from the remaining seconds. No re-send.
  /// - Session found, window elapsed -> land on this screen with the timer
  ///   at 0 (Resend enabled). No auto re-send.
  /// - No session -> normal flow: send now unless the caller already did
  ///   (skipInitialOtpRequest or forgot-password), otherwise persist the
  ///   session that the caller already created.
  Future<void> _restoreOrStart() async {
    final session = await _sessionStorage.load(_flow);
    final matches = session != null &&
        session.contact == widget.contact &&
        session.flow == _flow;

    if (matches) {
      final remaining = session.remainingSeconds;
      if (!mounted) return;
      setState(() => _resendTimer = remaining);
      if (remaining > 0) _startTimer();
      return;
    }

    _startTimer();
    if (!widget.isForgotPassword && !widget.skipInitialOtpRequest) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendInitialOtp());
    } else {
      // Caller already issued the OTP (login-checker or forgot-password
      // request). Anchor the persisted window so a cold start resumes
      // mid-countdown instead of restarting the full window.
      await _persistSession();
    }
  }

  Future<void> _persistSession() async {
    await _sessionStorage.save(PendingOtpSession(
      flow: _flow,
      contact: widget.contact,
      challengeId: null,
      isEmail: widget.isEmail,
      methodKey: widget.isEmail ? 'email' : 'sms',
      userId: widget.userId,
      sentAtMs: DateTime.now().millisecondsSinceEpoch,
      resendWindowSeconds: _resendWindow,
    ));
  }

  Future<void> _sendInitialOtp() async {
    try {
      final ok = await getIt<AuthRepository>().requestOtp(
        widget.contact,
        purpose: widget.isInitialSetup ? 'signup' : 'verification',
      );
      if (!mounted) {
        return;
      }
      if (!ok) {
        AppToast.error('Could not send verification code. Try again.');
        return;
      }
      await _persistSession();
      _startDeliveryStatusPolling();
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (e is DioException && isDioTransportFailure(e)) {
        _restartSplashColdStart();
        return;
      }
      final message = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
      AppToast.error(message);
    }
  }

  void _startDeliveryStatusPolling() {
    if (widget.isEmail || widget.isForgotPassword) return;
    _deliveryPollTimer?.cancel();
    _deliveryPollAttempts = 0;
    _deliveryPollTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      _deliveryPollAttempts++;
      if (_deliveryPollAttempts > 20) {
        timer.cancel();
        return;
      }
      try {
        final data = await getIt<AuthRepository>().getOtpDeliveryStatus(
          widget.contact,
          purpose: widget.isInitialSetup ? 'signup' : 'verification',
        );
        if (!mounted || data == null) return;
        final note = data['delivery_note']?.toString();
        final status = (data['status']?.toString() ?? '').toLowerCase();
        if (note != null && note.isNotEmpty) {
          setState(() {
            _deliveryInfo = note;
          });
        }
        if (status == 'sent' || status == 'failed') {
          timer.cancel();
        }
      } catch (_) {}
    });
  }

  void _startTimer() {
    _timer?.cancel();
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

  Future<void> _resendCode() async {
    if (_isResending) {
      return;
    }
    setState(() {
      _isResending = true;
    });
    try {
      if (widget.isForgotPassword) {
        try {
          await getIt<AuthRepository>().requestPasswordReset(widget.contact);
          if (!mounted) {
            return;
          }
          AppToast.success('A new code has been sent.');
        } catch (e) {
          if (!mounted) {
            return;
          }
          if (e is DioException && isDioTransportFailure(e)) {
            _restartSplashColdStart();
            return;
          }
          final message = e is Exception
              ? e.toString().replaceFirst('Exception: ', '')
              : e.toString();
          AppToast.error(message);
        }
      } else {
        try {
          final ok = await getIt<AuthRepository>().requestOtp(
            widget.contact,
            purpose: widget.isInitialSetup ? 'signup' : 'verification',
          );
          if (!mounted) {
            return;
          }
          if (ok) {
            AppToast.success('A new code has been sent.');
            _deliveryInfo = null;
            _startDeliveryStatusPolling();
          } else {
            AppToast.error('Could not resend code. Try again.');
          }
        } catch (e) {
          if (!mounted) {
            return;
          }
          if (e is DioException && isDioTransportFailure(e)) {
            _restartSplashColdStart();
            return;
          }
          final message = e is Exception
              ? e.toString().replaceFirst('Exception: ', '')
              : e.toString();
          AppToast.error(message);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
          _resendTimer = _resendWindow;
        });
        // Re-anchor the persisted session to "now" so the next cold start
        // resumes from this new send, not the original one.
        await _persistSession();
        _startTimer();
      }
    }
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
      if (widget.contact.length <= 7) {
        return '*' * widget.contact.length;
      }
      final start = widget.contact.substring(0, 3);
      final end = widget.contact.substring(widget.contact.length - 4);
      return '$start${'*' * (widget.contact.length - 7)}$end';
    }
  }

  Future<void> _verifyCode() async {
    if (_code.length != _otpLength) {
      return;
    }
    FocusScope.of(context).unfocus();

    setState(() {
      _isVerifying = true;
    });

    if (widget.isForgotPassword) {
      try {
        await getIt<AuthRepository>().verifyPasswordResetPin(
          widget.contact,
          _code,
        );
        if (!mounted) return;
        // Flow done — no stale timer should survive.
        await _sessionStorage.clear(_flow);
        // ignore: unawaited_futures
        context.push('/reset-password', extra: {
          'contact': widget.contact,
          'isEmail': widget.isEmail,
          'pin': _code,
        });
      } catch (e) {
        if (!mounted) return;
        if (e is DioException && isDioTransportFailure(e)) {
          _restartSplashColdStart();
          return;
        }
        final message = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : e.toString();
        AppToast.error(message);
        setState(() {
          _isVerifying = false;
          _code = '';
          _otpFieldKey++;
        });
      }
    } else {
      context.read<AuthBloc>().add(VerifyOtpRequested(
            contact: widget.contact,
            otp: _code,
            isInitialSetup: widget.isInitialSetup,
            userId: widget.userId,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),

              vSpace(12),

              // Instruction
              Center(
                child: Column(
                  children: [
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
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
                  ],
                ),
              ),

              vSpace(32),

              // OTP Input
              OtpInputField(
                key: ValueKey<int>(_otpFieldKey),
                length: _otpLength,
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
                        'Resend code in ${_resendTimer ~/ 60}:${(_resendTimer % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      )
                    : _isResending
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 18.w,
                                height: 18.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.primaryColor,
                                ),
                              ),
                              hSpace(8),
                              Text(
                                'Sending code…',
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Didn\'t receive the code?',
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                              hSpace(4),
                              TextButton(
                                onPressed: _resendCode,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Resend',
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    color: theme.brightness == Brightness.dark
                                        ? Colors.white
                                        : theme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),

              if (_deliveryInfo != null) ...[
                vSpace(10),
                Center(
                  child: Text(
                    _deliveryInfo!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: const Color(0xFF0F8B8D),
                    ),
                  ),
                ),
              ],

              vSpace(32),

              // Continue button
              BlocConsumer<AuthBloc, AuthState>(
                listener: (context, state) {
                  if (state is VerifyOtpSuccess) {
                    setState(() {
                      _isVerifying = false;
                    });
                    // Flow done — no stale timer should survive.
                    unawaited(_sessionStorage.clear(_flow));
                    // Navigate to reset password screen
                    context.push('/reset-password', extra: {
                      'userId': state.userId,
                      'contact': state.contact,
                      'isInitialSetup': widget.isInitialSetup,
                    });
                  } else if (state is AuthFailure) {
                    if (shouldRedirectToSplashForAuthFailure(state.error)) {
                      setState(() {
                        _isVerifying = false;
                        _code = '';
                        _otpFieldKey++;
                      });
                      _restartSplashColdStart();
                      return;
                    }
                    AppToast.error(state.error);
                    setState(() {
                      _isVerifying = false;
                      _code = '';
                      _otpFieldKey++;
                    });
                  }
                },
                builder: (context, state) {
                  // Only show loading when user has clicked the button
                  // _isVerifying is set to true only when user clicks
                  final isLoading = _isVerifying;
                  return AppElevatedButton(
                    title: 'Continue',
                    onPressed: (_code.length == _otpLength && !isLoading)
                        ? () => _verifyCode()
                        : null,
                    isLoading: isLoading,
                  );
                },
              ),

              vSpace(40),
            ],
          ),
        ),
      ),
    );
  }
}