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
import 'package:communal_mobile/data/models/otp_resend.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Completes login when another device was still signed in — OTP was sent during `/login`.
///
/// Resend stays locked while the code is valid and opens the moment it expires;
/// a resend starts a fresh window. Both that countdown and the moment the sign-in
/// step closes come from authsvc, which enforces the same rules.
class SessionTakeoverScreen extends StatefulWidget {
  const SessionTakeoverScreen({super.key});

  @override
  State<SessionTakeoverScreen> createState() => _SessionTakeoverScreenState();
}

class _SessionTakeoverScreenState extends State<SessionTakeoverScreen> {
  // Audit M25: single source of truth in [AppConstants.otpLength].
  static int get _otpLength => AppConstants.otpLength;

  /// The code window, for a backend that does not report one.
  static int get _fallbackCodeSeconds => AppConstants.otpResendWindowSeconds;

  final OtpSessionStorage _sessionStorage = OtpSessionStorage();

  int _otpFieldKey = 0;
  String _code = '';
  int _resendTimer = _fallbackCodeSeconds;
  DateTime? _stepExpiresAt;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isResending = false;
  bool _expiredHandled = false;
  String? _takeoverChallengeId;
  String _maskedDestination = '';
  String _otpChannel = 'phone';
  int? _serverResendIn;
  int? _serverStepExpiresIn;

  void _restartSplashColdStart() {
    if (!mounted) return;
    context.read<SplashCubit>().initApp();
    context.go('/');
  }

  @override
  void initState() {
    super.initState();
    _capturePendingState(includeCountdowns: true);
    _restoreOrStartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Seeds the countdowns. The server's figures win: they are what it enforces,
  /// and a login that found this challenge still open reports what is actually
  /// left of it. A persisted session for the same challenge is next, then the
  /// fallback window.
  Future<void> _restoreOrStartTimer() async {
    final challengeId = _takeoverChallengeId;
    if (challengeId == null) return;

    if (_serverResendIn != null) {
      _applyCountdowns(
        resendIn: _serverResendIn!,
        stepExpiresIn: _serverStepExpiresIn,
      );
      await _persistSession();
      return;
    }

    final session = await _sessionStorage.load(OtpFlow.sessionTakeover);
    if (!mounted) return;
    if (session != null && session.challengeId == challengeId) {
      _applyCountdowns(resendIn: session.remainingSeconds);
      return;
    }

    _applyCountdowns(resendIn: _fallbackCodeSeconds);
    await _persistSession();
  }

  void _applyCountdowns({required int resendIn, int? stepExpiresIn}) {
    if (!mounted) return;
    setState(() {
      _resendTimer = resendIn < 0 ? 0 : resendIn;
      if (stepExpiresIn != null) {
        _stepExpiresAt = DateTime.now().add(Duration(seconds: stepExpiresIn));
      }
    });
    _startTimer();
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
      resendWindowSeconds: _resendTimer,
    ));
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final stepExpiresAt = _stepExpiresAt;
      if (stepExpiresAt != null && !DateTime.now().isBefore(stepExpiresAt)) {
        timer.cancel();
        _onChallengeExpired();
        return;
      }
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else if (stepExpiresAt == null) {
        timer.cancel();
      }
    });
  }

  /// The sign-in step is gone on the server, so no code or resend can succeed.
  void _onChallengeExpired({String? message}) {
    if (_expiredHandled || !mounted) return;
    _expiredHandled = true;
    _timer?.cancel();
    unawaited(_sessionStorage.clear(OtpFlow.sessionTakeover));
    AppToast.error(message ?? 'This sign-in expired. Please log in again.');
    _goToLogin();
  }

  AuthSessionTakeoverPending? _pending(BuildContext context) {
    final s = context.read<AuthBloc>().state;
    return s is AuthSessionTakeoverPending ? s : null;
  }

  void _capturePendingState({bool includeCountdowns = false}) {
    final pending = _pending(context);
    if (pending == null) return;
    _takeoverChallengeId = pending.takeoverChallengeId;
    _maskedDestination = pending.maskedDestination;
    _otpChannel = pending.otpChannel;
    if (includeCountdowns) {
      _serverResendIn = pending.resendAvailableIn ?? pending.otpExpiresIn;
      _serverStepExpiresIn = pending.challengeExpiresIn;
    }
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
      final result =
          await getIt<AuthRepository>().resendSessionTakeoverOtp(challengeId);
      if (!mounted) return;
      setState(() {
        _otpFieldKey++;
        _code = '';
      });
      _applyCountdowns(
        resendIn: result.resendAvailableIn ??
            result.otpExpiresIn ??
            _fallbackCodeSeconds,
        stepExpiresIn: result.challengeExpiresIn,
      );
      await _persistSession();
      AppToast.success('A new code was sent.');
    } on OtpResendException catch (e) {
      if (!mounted) return;
      if (e.challengeExpired) {
        _onChallengeExpired(message: e.message);
        return;
      }
      final wait = e.retryAfterSeconds;
      if (wait != null && wait > 0) _applyCountdowns(resendIn: wait);
      AppToast.error(e.message);
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

  String _clock(int seconds) =>
      '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

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
          // A new challenge id means the backend issued a fresh OTP — take its
          // countdowns and persist.
          if (changed) {
            _expiredHandled = false;
            _applyCountdowns(
              resendIn: state.resendAvailableIn ??
                  state.otpExpiresIn ??
                  _fallbackCodeSeconds,
              stepExpiresIn: state.challengeExpiresIn,
            );
            _persistSession();
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
          final error = state.error.toLowerCase();
          if (error.contains('sign-in step expired') ||
              error.contains('log in again')) {
            _onChallengeExpired(message: state.error);
            return;
          }
          if (!error.contains('cancelled')) {
            AppToast.error(state.error);
          }
        }
      },
      builder: (context, state) {
        final verifying = _isVerifying;
        final codeExpired = _resendTimer == 0;
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
                  if (codeExpired && !_isResending) ...[
                    vSpace(8),
                    Text(
                      'This code has expired. Request a new one.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ],
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
                    onPressed: (!codeExpired || _isResending || verifying)
                        ? null
                        : _resend,
                    child: Text(
                      !codeExpired
                          ? 'Resend code in ${_clock(_resendTimer)}'
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
