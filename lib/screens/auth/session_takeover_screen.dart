import 'dart:async';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/constants/constants.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/services/otp_session_storage.dart';
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
  static int get _resendWindow => AppConstants.otpResendWindowSeconds;

  final OtpSessionStorage _sessionStorage = OtpSessionStorage();

  int _otpFieldKey = 0;
  String _code = '';
  int _resendTimer = _resendWindow;
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
    _capturePendingState();
    _restoreOrStartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Resumes the countdown from a persisted session for this exact challenge
  /// id if one exists (app was closed and reopened mid-takeover), otherwise
  /// starts a fresh window. Persisting + resuming here means a user can't
  /// force a resend by killing the app: the countdown is anchored to the
  /// moment the OTP was actually sent, not to when the screen mounted.
  Future<void> _restoreOrStartTimer() async {
    final challengeId = _takeoverChallengeId;
    final session = await _sessionStorage.load(OtpFlow.sessionTakeover);
    final matches = session != null &&
        challengeId != null &&
        session.challengeId == challengeId;

    if (matches) {
      final remaining = session.remainingSeconds;
      if (!mounted) return;
      setState(() => _resendTimer = remaining);
      if (remaining > 0) _startTimer();
      return;
    }

    _startTimer();
    // Persist the freshly-issued challenge so a cold start before the window
    // elapses resumes mid-countdown rather than restarting the full window.
    await _persistSession();
  }

  Future<void> _persistSession() async {
    final challengeId = _takeoverChallengeId;
    if (challengeId == null || challengeId.isEmpty) return;
    await _sessionStorage.save(PendingOtpSession(
      flow: OtpFlow.sessionTakeover,
      contact: '',
      challengeId: challengeId,
      isEmail: _otpChannel == 'email',
      methodKey: _otpChannel,
      userId: null,
      sentAtMs: DateTime.now().millisecondsSinceEpoch,
      resendWindowSeconds: _resendWindow,
    ));
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
    if (_code.length != _otpLength || _isVerifying || challengeId == null) {
      return;
    }
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
        _resendTimer = _resendWindow;
        _otpFieldKey++;
        _code = '';
      });
      // Re-anchor the persisted session to "now" so the next cold start
      // resumes from this new send, not the original one.
      await _persistSession();
      _startTimer();
      AppToast.success('A new code was sent.');
    } catch (e) {
      if (!mounted) return;
      if (e is DioException && isDioTransportFailure(e)) {
        _restartSplashColdStart();
        return;
      }
      final msg = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : e.toString();
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
          c is AuthAuthenticated ||
          c is AuthFailure ||
          c is AuthSessionTakeoverPending,
      listener: (context, state) {
        if (state is AuthSessionTakeoverPending) {
          final changed = state.takeoverChallengeId != _takeoverChallengeId;
          _takeoverChallengeId = state.takeoverChallengeId;
          _maskedDestination = state.maskedDestination;
          _otpChannel = state.otpChannel;
          // A new challenge id means the backend issued a fresh OTP —
          // restart the window and persist.
          if (changed) {
            setState(() => _resendTimer = _resendWindow);
            _persistSession();
            _startTimer();
          }
          return;
        }
        if (state is AuthAuthenticated) {
          setState(() => _isVerifying = false);
          // Takeover done — no stale timer should survive into the session.
          unawaited(_sessionStorage.clear(OtpFlow.sessionTakeover));
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
          backgroundColor: Theme.of(context).cardColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: verifying ? null : _goToLogin,
            ),
          ),
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Image.asset(
                      Theme.of(context).brightness == Brightness.dark
                          ? Images.whiteLogo
                          : Images.coloredLogo,
                      width: 140.w,
                    ),
                  ),
                  vSpace(28),
                  Text(
                    'Confirm new sign-in',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  vSpace(10),
                  Text(
                    'Another device is still signed in. Enter the code we sent to your $channelLabel (${_maskedDestination.isEmpty ? 'your account contact' : _maskedDestination}).',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17.sp,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
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
                    onPressed:
                        (verifying || _code.length != _otpLength) ? null : _verify,
                    isLoading: verifying,
                  ),
                  vSpace(20),
                  TextButton(
                    onPressed: (_resendTimer > 0 || _isResending || verifying)
                        ? null
                        : _resend,
                    child: Text(
                      _resendTimer > 0
                          ? 'Resend code in ${_resendTimer ~/ 60}:${(_resendTimer % 60).toString().padLeft(2, '0')}'
                          : (_isResending ? 'Sending…' : 'Resend code'),
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Theme.of(context).primaryColor,
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