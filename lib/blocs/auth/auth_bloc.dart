import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/security/token_manager.dart';
import 'package:communal_mobile/core/utils/app_logger.dart';
import 'package:communal_mobile/core/utils/dio_transport_user_message.dart';
import 'package:communal_mobile/data/local/kyc_progress_storage.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  static const String _tag = 'AuthBloc';

  final AuthRepository authRepository;
  final FlutterSecureStorage secureStorage;
  final TokenManager tokenManager;

  // CRITICAL: Track if we just had a failed login attempt
  // This prevents AppStarted from unlocking with a cached token after password failure
  bool _hasRecentFailedLogin = false;

  /// Increments on each [LoginRequested] so [AuthVerifyingCredentials] is always unique.
  int _credentialVerifyAttemptId = 0;

  /// Increments on each successful [LoginRequested] so [AuthAuthenticated] is never == prior AppStarted.
  int _loginSessionGeneration = 0;

  AuthBloc({
    required this.authRepository,
    required this.secureStorage,
    required this.tokenManager,
  }) : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<AuthUserUpdated>(_onAuthUserUpdated);
    on<AuthRefreshUserRequested>(_onAuthRefreshUserRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<CheckLoginRequested>(_onCheckLoginRequested);
    on<VerifyOtpRequested>(_onVerifyOtpRequested);
    on<CreatePasswordRequested>(_onCreatePasswordRequested);
    on<ResetPasswordRequested>(_onResetPasswordRequested);
    on<SessionTakeoverVerifyRequested>(_onSessionTakeoverVerifyRequested);
    on<SessionTakeoverCancelled>(_onSessionTakeoverCancelled);
  }

  /// Extract clean error message from exception
  String _extractErrorMessage(dynamic error) {
    if (error is Exception) {
      final errorStr = error.toString();
      // Remove "Exception: " prefix if present
      if (errorStr.startsWith('Exception: ')) {
        return errorStr.substring(11);
      }
      return errorStr;
    }
    return error.toString();
  }

  String _messageForAuthFailure(dynamic e) {
    if (e is DioException && isDioTransportFailure(e)) {
      return dioTransportUserMessage(e);
    }
    return _extractErrorMessage(e);
  }

  /// Calls [AuthRepository.getUserInfo] with a small retry loop so a
  /// transient backend blip after a successful login doesn't cost the user
  /// a correctly-typed PIN. Retries on `null` returns and on
  /// [DioException]; non-network exceptions propagate immediately.
  ///
  /// Three attempts total with a short backoff (~250ms then ~750ms) — fast
  /// enough that the loader on the welcome-back screen still feels
  /// responsive, generous enough to ride out a single packet drop on 4G.
  Future<UserModel?> _getUserInfoWithRetry(String token) async {
    const delays = [Duration(milliseconds: 250), Duration(milliseconds: 750)];
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final user = await authRepository.getUserInfo(token);
        if (user != null) return user;
      } on DioException {
        // Network blip — retry within budget.
      }
      if (attempt < delays.length) {
        await Future.delayed(delays[attempt]);
      }
    }
    return null;
  }

  Future<void> _hydrateKycResumeFromBackend(UserModel user) async {
    final userId = user.id;
    if (userId.trim().isEmpty) return;
    final storage = getIt<KycProgressStorage>();
    final anchor = user.kycAnchorCustomerId?.trim();
    if (anchor != null && anchor.isNotEmpty && user.kycStep1Submitted) {
      await storage.ensureAnchorSynced(userId, anchor);
    }

    // Backend is the source of truth across sessions/devices.
    if (user.kycStep3Submitted) {
      await storage.setResumeStep(userId, 3);
      return;
    }
    if (user.kycStep2Submitted) {
      await storage.setResumeStep(userId, 2);
      return;
    }
    if (user.kycStep1Submitted) {
      final current = storage.getResumeStep(userId);
      // Keep local progress (e.g. user skipped bank → step 2) until the server records tier 1.
      final next = current >= 2 ? current : 1;
      await storage.setResumeStep(userId, next);
      return;
    }
    await storage.setResumeStep(userId, 0);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    AppLogger.debug(
        _tag, 'AppStarted failedLogin=$_hasRecentFailedLogin');

    if (_hasRecentFailedLogin) {
      Future.delayed(const Duration(seconds: 5), () {
        _hasRecentFailedLogin = false;
      });
      emit(AuthUnauthenticated());
      return;
    }

    emit(AuthLoading());

    try {
      // Audit M6: hydrate the access + refresh tokens into TokenManager
      // before any request goes out. The dio refresh interceptor reads
      // from this state to decide proactive vs reactive refresh.
      await tokenManager.hydrate();
      final token = tokenManager.accessToken;
      AppLogger.debug(_tag, 'AppStarted tokenPresent=${token != null}');

      if (token != null) {
        try {
          final user = await authRepository.getUserInfo(token);
          if (user != null) {
            await _hydrateKycResumeFromBackend(user);
            // Audit M5: session identifier is server-vouched on every cold
            // start (`/get-loggedin-user`), never read from local storage.
            emit(AuthAuthenticated(
              userId: user.id,
              login: user.login.trim(),
              user: user,
              sessionGeneration: 0,
            ));
          } else {
            await tokenManager.clear();
            emit(AuthUnauthenticated());
          }
        } catch (e) {
          // Offline / transient network: do not clear tokens — splash will retry when online.
          if (e is DioException &&
              (e.type == DioExceptionType.connectionError ||
                  e.type == DioExceptionType.connectionTimeout ||
                  e.type == DioExceptionType.sendTimeout ||
                  e.type == DioExceptionType.receiveTimeout)) {
            emit(AuthUnauthenticated());
            return;
          }
          await tokenManager.clear();
          emit(AuthUnauthenticated());
        }
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e, st) {
      AppLogger.error(_tag, 'AppStarted error', error: e, stackTrace: st);
      try {
        await tokenManager.clear();
      } catch (_) {}
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthVerifyingCredentials(++_credentialVerifyAttemptId));

    try {
      final loginResponse = await authRepository.login(
        event.login,
        event.password,
      );

      if (loginResponse != null && loginResponse.requiresSessionTakeoverOtp) {
        final id = loginResponse.takeoverChallengeId;
        if (id != null && id.isNotEmpty) {
          emit(AuthSessionTakeoverPending(
            takeoverChallengeId: id,
            maskedDestination: loginResponse.maskedDestination ?? '',
            otpChannel: loginResponse.otpChannel ?? 'phone',
            login: event.login.trim(),
            message: loginResponse.message,
          ));
          return;
        }
      }

      if (loginResponse != null && loginResponse.token != null) {
        // Audit M6: persist via TokenManager so the refresh interceptor
        // sees the new access + refresh + expiry. Updates dio's default
        // header too, so the immediate `getUserInfo` below uses it.
        await tokenManager.updateTokens(
          accessToken: loginResponse.token!,
          refreshToken: loginResponse.refreshToken,
          expiresIn: loginResponse.expiresIn,
        );

        // Login succeeded (token is persisted and valid). Fetching the
        // profile is a separate request and can hit transient blips —
        // retry a few times before deciding it's a real failure, so a
        // momentary network hiccup doesn't waste a correctly-typed PIN.
        final user = await _getUserInfoWithRetry(loginResponse.token!);

        if (user != null) {
          // Audit M5: persist only the opaque user id, never the email/phone
          // login. Email/phone in Keystore extracts to PII; the integer user
          // id does not.
          await secureStorage.write(key: 'user_id', value: user.id);
          await _hydrateKycResumeFromBackend(user);
          _hasRecentFailedLogin = false;
          emit(AuthAuthenticated(
            userId: user.id,
            login: user.login.trim(),
            user: user,
            sessionGeneration: ++_loginSessionGeneration,
          ));
        } else {
          // Profile fetch failed across all retries. The session token is
          // still valid in secure storage; surface a user-visible error so
          // the user gets explicit feedback instead of a silent reset
          // (legacy behavior was to emit [AuthUnauthenticated] here, which
          // the welcome-back screen's outer listener swallowed without a
          // message, making a correct PIN look like it had been ignored).
          emit(const AuthFailure(
            'Could not load your profile. Please try again.',
          ));
        }
      } else {
        emit(AuthFailure(
          loginResponse?.message ?? 'Invalid login response',
        ));
      }
    } on DioException catch (e) {
      // Audit M33: typed catch so the user-facing message goes through
      // the transport-aware mapper.
      final errorMsg = _messageForAuthFailure(e);
      final hasExistingToken = (tokenManager.accessToken?.isNotEmpty ?? false);
      if (!hasExistingToken) {
        AppLogger.debug(_tag, 'LoginFailed fresh attempt (no prior token)');
      }
      _hasRecentFailedLogin = true;
      emit(AuthFailure(errorMsg));
    } catch (e, st) {
      // Audit M33: anything else is unexpected — log with stack so the
      // failure shape isn't lost, then surface a generic user message.
      AppLogger.error(_tag, 'LoginRequested unexpected error',
          error: e, stackTrace: st);
      _hasRecentFailedLogin = true;
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  Future<void> _onSessionTakeoverVerifyRequested(
    SessionTakeoverVerifyRequested event,
    Emitter<AuthState> emit,
  ) async {
    final pending = state;
    if (pending is! AuthSessionTakeoverPending) {
      return;
    }
    final loginToStore = pending.login;

    try {
      final loginResponse = await authRepository.verifySessionTakeover(
        event.challengeId,
        event.otp,
      );

      if (loginResponse != null && loginResponse.token != null) {
        // Audit M6: persist via TokenManager (access + refresh + expiry).
        await tokenManager.updateTokens(
          accessToken: loginResponse.token!,
          refreshToken: loginResponse.refreshToken,
          expiresIn: loginResponse.expiresIn,
        );
        authRepository.updateToken(loginResponse.token!);
        final user = await authRepository.getUserInfo(loginResponse.token!);
        if (user != null) {
          // Audit M5: opaque user id only — see `_onLoginRequested` notes.
          await secureStorage.write(key: 'user_id', value: user.id);
          await _hydrateKycResumeFromBackend(user);
          _hasRecentFailedLogin = false;
          emit(AuthAuthenticated(
            userId: user.id,
            login: loginToStore.isNotEmpty ? loginToStore : user.login.trim(),
            user: user,
            sessionGeneration: ++_loginSessionGeneration,
          ));
        } else {
          emit(const AuthFailure('Could not load your profile.'));
        }
      } else {
        final error = loginResponse?.message ?? 'Invalid sign-in response';
        emit(AuthFailure(error));
        emit(AuthSessionTakeoverPending(
          takeoverChallengeId: pending.takeoverChallengeId,
          maskedDestination: pending.maskedDestination,
          otpChannel: pending.otpChannel,
          login: pending.login,
          message: error,
        ));
      }
    } on DioException catch (e) {
      // Audit M33: typed catch — transport-aware message.
      final error = _messageForAuthFailure(e);
      emit(AuthFailure(error));
      emit(AuthSessionTakeoverPending(
        takeoverChallengeId: pending.takeoverChallengeId,
        maskedDestination: pending.maskedDestination,
        otpChannel: pending.otpChannel,
        login: pending.login,
        message: error,
      ));
    } catch (e, st) {
      // Audit M33: log unexpected exceptions with stack trace.
      AppLogger.error(_tag, 'SessionTakeoverVerify unexpected error',
          error: e, stackTrace: st);
      final error = _extractErrorMessage(e);
      emit(AuthFailure(error));
      emit(AuthSessionTakeoverPending(
        takeoverChallengeId: pending.takeoverChallengeId,
        maskedDestination: pending.maskedDestination,
        otpChannel: pending.otpChannel,
        login: pending.login,
        message: error,
      ));
    }
  }

  void _onSessionTakeoverCancelled(
    SessionTakeoverCancelled event,
    Emitter<AuthState> emit,
  ) {
    emit(const AuthFailure(
      'Verification cancelled. Enter your password again.',
    ));
  }

  void _onAuthUserUpdated(AuthUserUpdated event, Emitter<AuthState> emit) {
    final s = state;
    if (s is! AuthAuthenticated) return;
    final u = event.user;
    emit(AuthAuthenticated(
      userId: u.id.isNotEmpty ? u.id : s.userId,
      login: s.login,
      user: u,
      sessionGeneration: s.sessionGeneration + 1,
    ));
  }

  Future<void> _onAuthRefreshUserRequested(
    AuthRefreshUserRequested event,
    Emitter<AuthState> emit,
  ) async {
    final s = state;
    if (s is! AuthAuthenticated) return;
    final token = tokenManager.accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final user = await authRepository.getUserInfo(token);
      if (user != null) {
        await _hydrateKycResumeFromBackend(user);
        emit(AuthAuthenticated(
          userId: user.id.isNotEmpty ? user.id : s.userId,
          login: s.login,
          user: user,
          sessionGeneration: s.sessionGeneration + 1,
        ));
      }
    } catch (_) {
      // Silent: polling must not log the user out on transient errors.
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Clear ALL user-related keys from secure storage (preserve app-level
    // settings like onboarding_completed). The onboarding flag persists
    // through logout but is cleared on app uninstall.
    await tokenManager.clear(); // access + refresh + expiry (audit M6)
    await secureStorage.delete(key: 'user_id');
    // Back-compat: clear the legacy 'login' key so devices upgrading from
    // pre-audit-M5 builds don't carry forward the cached PII identifier.
    await secureStorage.delete(key: 'login');
    emit(AuthUnauthenticated());
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    final token = tokenManager.accessToken;

    if (token != null) {
      final user = await authRepository.getUserInfo(token);
      if (user != null) {
        await _hydrateKycResumeFromBackend(user);
        // Audit M5: server-vouched login only.
        emit(AuthAuthenticated(
          userId: user.id,
          login: user.login.trim(),
          user: user,
          sessionGeneration: 0,
        ));
      } else {
        emit(AuthUnauthenticated());
      }
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onCheckLoginRequested(
    CheckLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final result = await authRepository.checkLogin(event.login);

      if (result != null && result['hasPassword'] != null && result['userId'] != null && result['login'] != null) {
        emit(CheckLoginSuccess(
          hasPassword: result['hasPassword'] as bool,
          userId: result['userId'] as String,
          login: result['login'] as String,
          nextStep: result['nextStep'] as String?,
          otpSent: result['otpSent'] as bool?,
          otpDeliveryMessage: result['otpDeliveryMessage'] as String?,
        ));
      } else {
        emit(const AuthFailure('User not found'));
      }
    } catch (e) {
      emit(AuthFailure(_messageForAuthFailure(e)));
    }
  }

  Future<void> _onVerifyOtpRequested(
    VerifyOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final isValid = await authRepository.verifyOtp(
        event.contact,
        event.otp,
      );

      if (isValid) {
        emit(VerifyOtpSuccess(
          userId: event.userId ?? '',
          contact: event.contact,
        ));
      } else {
        emit(const AuthFailure('Invalid OTP code'));
      }
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  Future<void> _onCreatePasswordRequested(
    CreatePasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      if (event.password != event.confirmPassword) {
        emit(const AuthFailure('Passwords do not match'));
        return;
      }

      // Password must be exactly 6 digits (numeric only) for mobile
      if (event.password.length != 6) {
        emit(const AuthFailure('Password must be exactly 6 digits'));
        return;
      }

      // Check if password is numeric only
      if (!RegExp(r'^[0-9]+$').hasMatch(event.password)) {
        emit(const AuthFailure('Password must contain only numbers'));
        return;
      }

      // Brute force prevention: reject all-same-digit PINs.
      final firstChar = event.password[0];
      if (event.password.split('').every((char) => char == firstChar)) {
        emit(const AuthFailure('Password cannot be all the same digit. Please use a mix of different numbers.'));
        return;
      }

      final loginResponse = await authRepository.createPassword(
        event.userId,
        event.password,
      );

      if (loginResponse?.token != null) {
        // Token was returned, save it and authenticate
        final token = loginResponse!.token!;
        // Audit M6: persist via TokenManager (access + refresh + expiry).
        await tokenManager.updateTokens(
          accessToken: token,
          refreshToken: loginResponse.refreshToken,
          expiresIn: loginResponse.expiresIn,
        );
        authRepository.updateToken(token);

        try {
          final user = await authRepository.getUserInfo(token);
          if (user != null) {
            // Audit M5: opaque user id, never the contact identifier.
            await secureStorage.write(key: 'user_id', value: user.id);
            // Prefer OTP / login-checker contact for the in-memory session
            // label (email or phone the user actually typed). API
            // user.login favors email; this respects the user's choice.
            final fromContact = event.contact?.trim() ?? '';
            final sessionLogin = fromContact.isNotEmpty
                ? fromContact
                : user.login.trim();
            emit(CreatePasswordSuccess(token: token));
            emit(AuthAuthenticated(
              userId: user.id,
              login: sessionLogin,
              user: user,
              sessionGeneration: ++_loginSessionGeneration,
            ));
          } else {
            // Password was set, but couldn't get user info — still success.
            // No identifier persisted (audit M5); the next launch will fetch
            // fresh user info via /get-loggedin-user.
            emit(CreatePasswordSuccess(token: token));
          }
        } catch (userInfoError) {
          AppLogger.warn(_tag,
              'createPassword: getUserInfo failed (${userInfoError.runtimeType})');
          // Password was set successfully, but user info fetch failed.
          // Still emit success since password creation worked. Audit M5:
          // no identifier persisted on the failure path either.
          emit(CreatePasswordSuccess(token: token));
        }
      } else {
        // No token returned, need to login after password creation
        emit(CreatePasswordSuccess(token: null));
      }
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'createPassword failed',
          error: e, stackTrace: stackTrace);
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  Future<void> _onResetPasswordRequested(
    ResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      // Reset password via API
      final success = await authRepository.resetPassword(
        event.login,
        event.newPassword,
        event.pin,
      );

      if (success) {
        // After successful password reset, automatically log the user in
        final loginResponse = await authRepository.login(
          event.login,
          event.newPassword,
        );

        if (loginResponse != null && loginResponse.token != null) {
          // Audit M6: persist via TokenManager (access + refresh + expiry).
          await tokenManager.updateTokens(
            accessToken: loginResponse.token!,
            refreshToken: loginResponse.refreshToken,
            expiresIn: loginResponse.expiresIn,
          );

          final user = await authRepository.getUserInfo(loginResponse.token!);

          if (user != null) {
            // Audit M5: persist only the opaque user id.
            await secureStorage.write(key: 'user_id', value: user.id);
            emit(ResetPasswordSuccess());
            emit(AuthAuthenticated(
              userId: user.id,
              login: event.login.trim(),
              user: user,
              sessionGeneration: ++_loginSessionGeneration,
            ));
          } else {
            emit(ResetPasswordSuccess());
            emit(AuthUnauthenticated());
          }
        } else {
          // Password reset succeeded but login failed.
          emit(ResetPasswordSuccess());
          emit(const AuthFailure("Password reset successful, but login failed. Please try logging in manually."));
        }
      } else {
        emit(const AuthFailure("Failed to reset password. Please try again."));
      }
    } catch (e, stackTrace) {
      AppLogger.warn(_tag, 'resetPassword failed', error: e);
      AppLogger.debug(_tag, 'stack', stackTrace: stackTrace);
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }
}
