import 'dart:async';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/constants/constants.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/otp_input_field.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/utils/dio_transport_user_message.dart';
import 'package:communal_mobile/cubits/splash/splash_cubit.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Completes login when another device was still signed in — OTP was sent during `/login`.
class SessionTakeoverScreen extends StatefulWidget {
  const SessionTakeoverScreen({super.key});

  @override
  State<SessionTakeoverScreen> createState() => _SessionTakeoverScreenState();
}

class _SessionTakeoverScreenState extends State<SessionTakeoverScreen> {
  // Audit M25: single source of truth in [AppConstants.otpLength].
  static int get _otpLength => AppConstants.otpLength;

  int _otpFieldKey = 0;
  String _code = '';
  int _resendTimer = 60;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _takeoverChallengeId;
  String _maskedDestination = '';
  String _otpChannel = 'phone';

  void _restartSplashColdStart() {
    if (!mounted) return;
    context.read<SplashCubit>().initApp();
    context.go('/');
  }

  @override
  void initState() {
    super.initState();
    _startTimer();
    _capturePendingState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        if (mounted) {
          setState(() => _resendTimer--);
        }
      } else {
        timer.cancel();
      }
    });
  }

  AuthSessionTakeoverPending? _pending(BuildContext context) {
    final s = context.read<AuthBloc>().state;
    return s is AuthSessionTakeoverPending ? s : null;
  }

  void _capturePendingState() {
    final pending = _pending(context);
    if (pending == null) return;
    _takeoverChallengeId = pending.takeoverChallengeId;
    _maskedDestination = pending.maskedDestination;
    _otpChannel = pending.otpChannel;
  }

  void _goToLogin() {
    if (!mounted) return;
    context.go('/login');
  }

  Future<void> _verify() async {
    final challengeId = _takeoverChallengeId;
    if (_code.length != _otpLength || _isVerifying || challengeId == null) return;
    if (challengeId.isEmpty) {
      _goToLogin();
      return;
    }
    setState(() => _isVerifying = true);
    context.read<AuthBloc>().add(
          SessionTakeoverVerifyRequested(
            challengeId: challengeId,
            otp: _code,
          ),
        );
  }

  Future<void> _resend() async {
    final challengeId = _takeoverChallengeId;
    if (_resendTimer > 0 || _isResending || challengeId == null) return;
    setState(() => _isResending = true);
    try {
      await getIt<AuthRepository>().resendSessionTakeoverOtp(challengeId);
      if (!mounted) return;
      setState(() {
        _resendTimer = 60;
        _otpFieldKey++;
        _code = '';
      });
      _startTimer();
      AppToast.success('A new code was sent.');
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && isDioTransportFailure(e)) {
        _restartSplashColdStart();
        return;
      }
      final msg =
          e is Exception ? e.toString().replaceFirst('Exception: ', '') : e.toString();
      AppToast.error(msg);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _capturePendingState();
    if (_takeoverChallengeId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _goToLogin());
    }

    final channelLabel = _otpChannel == 'email' ? 'email' : 'phone number';

    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (p, c) =>
          c is AuthAuthenticated || c is AuthFailure || c is AuthSessionTakeoverPending,
      listener: (context, state) {
        if (state is AuthSessionTakeoverPending) {
          _takeoverChallengeId = state.takeoverChallengeId;
          _maskedDestination = state.maskedDestination;
          _otpChannel = state.otpChannel;
          return;
        }
        if (state is AuthAuthenticated) {
          setState(() => _isVerifying = false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go('/home');
          });
          return;
        }
        if (state is AuthFailure) {
          if (shouldRedirectToSplashForAuthFailure(state.error)) {
            setState(() {
              _isVerifying = false;
              _otpFieldKey++;
              _code = '';
            });
            _restartSplashColdStart();
            return;
          }
          setState(() {
            _isVerifying = false;
            _otpFieldKey++;
            _code = '';
          });
          if (!state.error.toLowerCase().contains('cancelled')) {
            AppToast.error(state.error);
          }
        }
      },
      builder: (context, state) {
        final verifying = _isVerifying;
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: verifying
                  ? null
                  : _goToLogin,
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(Images.coloredLogo, width: 140.w),
                  ),
                  vSpace(28),
                  Text(
                    'Confirm new sign-in',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F1D40),
                    ),
                  ),
                  vSpace(10),
                  Text(
                    'Another device is still signed in. Enter the code we sent to your $channelLabel (${_maskedDestination.isEmpty ? 'your account contact' : _maskedDestination}).',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: Colors.grey.shade700,
                      height: 1.35,
                    ),
                  ),
                  vSpace(32),
                  OtpInputField(
                    key: ValueKey(_otpFieldKey),
                    length: _otpLength,
                    onChanged: (v) => _code = v,
                    onCompleted: (_) => _verify(),
                  ),
                  vSpace(28),
                  AppElevatedButton(
                    title: verifying ? 'Verifying…' : 'Continue',
                    onPressed: (verifying || _code.length != _otpLength) ? null : _verify,
                    isLoading: verifying,
                  ),
                  vSpace(20),
                  TextButton(
                    onPressed: (_resendTimer > 0 || _isResending || verifying) ? null : _resend,
                    child: Text(
                      _resendTimer > 0
                          ? 'Resend code in ${_resendTimer}s'
                          : (_isResending ? 'Sending…' : 'Resend code'),
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
