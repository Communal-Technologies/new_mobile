import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
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

  // CRITICAL: Track if we just had a failed login attempt
  // This prevents AppStarted from unlocking with a cached token after password failure
  bool _hasRecentFailedLogin = false;

  /// Increments on each [LoginRequested] so [AuthVerifyingCredentials] is always unique.
  int _credentialVerifyAttemptId = 0;

  /// Increments on each successful [LoginRequested] so [AuthAuthenticated] is never == prior AppStarted.
  int _loginSessionGeneration = 0;

  AuthBloc({required this.authRepository, required this.secureStorage})
    : super(AuthInitial()) {
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
      final token = await secureStorage.read(key: 'token');
      AppLogger.debug(_tag, 'AppStarted tokenPresent=${token != null}');

      if (token != null) {
        try {
          final user = await authRepository.getUserInfo(token);
          if (user != null) {
            await _hydrateKycResumeFromBackend(user);
            final storedLogin = (await secureStorage.read(key: 'login'))?.trim() ?? '';
            final sessionLogin =
                storedLogin.isNotEmpty ? storedLogin : user.login.trim();
            emit(AuthAuthenticated(
              userId: user.id,
              login: sessionLogin,
              user: user,
              sessionGeneration: 0,
            ));
          } else {
            await secureStorage.delete(key: 'token');
            emit(AuthUnauthenticated());
          }
        } catch (e) {
          // Offline / transient network: do not clear token — splash will retry when online.
          if (e is DioException &&
              (e.type == DioExceptionType.connectionError ||
                  e.type == DioExceptionType.connectionTimeout ||
                  e.type == DioExceptionType.sendTimeout ||
                  e.type == DioExceptionType.receiveTimeout)) {
            emit(AuthUnauthenticated());
            return;
          }
          await secureStorage.delete(key: 'token');
          emit(AuthUnauthenticated());
        }
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e, st) {
      AppLogger.error(_tag, 'AppStarted error', error: e, stackTrace: st);
      try {
        await secureStorage.delete(key: 'token');
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
        await secureStorage.write(key: 'token', value: loginResponse.token!);
        await secureStorage.write(key: 'login', value: event.login);

        final user = await authRepository.getUserInfo(loginResponse.token!);

        if (user != null) {
          await _hydrateKycResumeFromBackend(user);
          _hasRecentFailedLogin = false;
          emit(AuthAuthenticated(
            userId: user.id,
            login: event.login.trim(),
            user: user,
            sessionGeneration: ++_loginSessionGeneration,
          ));
        } else {
          emit(AuthUnauthenticated());
        }
      } else {
        emit(AuthFailure(
          loginResponse?.message ?? 'Invalid login response',
        ));
      }
    } catch (e) {
      final errorMsg = _messageForAuthFailure(e);
      final existingToken = await secureStorage.read(key: 'token');
      final hasExistingToken = existingToken != null && existingToken.isNotEmpty;
      if (!hasExistingToken) {
        AppLogger.debug(_tag, 'LoginFailed fresh attempt (no prior token)');
      }
      _hasRecentFailedLogin = true;
      emit(AuthFailure(errorMsg));
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
        await secureStorage.write(key: 'token', value: loginResponse.token!);
        if (loginToStore.isNotEmpty) {
          await secureStorage.write(key: 'login', value: loginToStore);
        }
        authRepository.updateToken(loginResponse.token!);
        final user = await authRepository.getUserInfo(loginResponse.token!);
        if (user != null) {
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
    } catch (e) {
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
    final token = await secureStorage.read(key: 'token');
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
    await secureStorage.delete(key: 'token');
    await secureStorage.delete(key: 'login');
    emit(AuthUnauthenticated());
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    final token = await secureStorage.read(key: 'token');

    if (token != null) {
      final user = await authRepository.getUserInfo(token);
      if (user != null) {
        await _hydrateKycResumeFromBackend(user);
        final storedLogin = (await secureStorage.read(key: 'login'))?.trim() ?? '';
        final sessionLogin =
            storedLogin.isNotEmpty ? storedLogin : user.login.trim();
        emit(AuthAuthenticated(
          userId: user.id,
          login: sessionLogin,
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
        await secureStorage.write(key: 'token', value: token);
        authRepository.updateToken(token);

        try {
          final user = await authRepository.getUserInfo(token);
          if (user != null) {
            // Prefer OTP / login-checker contact (email or phone as user used); API user.login favors email.
            final fromContact = event.contact?.trim() ?? '';
            final loginToStore = fromContact.isNotEmpty
                ? fromContact
                : (user.login.trim().isNotEmpty ? user.login.trim() : '');
            if (loginToStore.isNotEmpty) {
              await secureStorage.write(key: 'login', value: loginToStore);
            }
            emit(CreatePasswordSuccess(token: token));
            emit(AuthAuthenticated(
              userId: user.id,
              login: loginToStore.isNotEmpty ? loginToStore : user.login.trim(),
              user: user,
              sessionGeneration: ++_loginSessionGeneration,
            ));
          } else {
            final fallbackLogin = event.contact?.trim() ?? '';
            if (fallbackLogin.isNotEmpty) {
              await secureStorage.write(key: 'login', value: fallbackLogin);
            }
            // Password was set, but couldn't get user info - still success
            emit(CreatePasswordSuccess(token: token));
          }
        } catch (userInfoError) {
          AppLogger.warn(_tag,
              'createPassword: getUserInfo failed (${userInfoError.runtimeType})');
          final fallbackLogin = event.contact?.trim() ?? '';
          if (fallbackLogin.isNotEmpty) {
            await secureStorage.write(key: 'login', value: fallbackLogin);
          }
          // Password was set successfully, but user info fetch failed
          // Still emit success since password creation worked
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
          await secureStorage.write(key: 'token', value: loginResponse.token!);
          // Store login for reference (password not stored).
          await secureStorage.write(key: 'login', value: event.login);

          final user = await authRepository.getUserInfo(loginResponse.token!);

          if (user != null) {
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
