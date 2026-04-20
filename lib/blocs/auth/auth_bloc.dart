import 'dart:developer' as developer;
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/app_logger.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
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
    on<CheckAuthStatus>(_onCheckAuthStatus);
    on<CheckLoginRequested>(_onCheckLoginRequested);
    on<VerifyOtpRequested>(_onVerifyOtpRequested);
    on<CreatePasswordRequested>(_onCreatePasswordRequested);
    on<ResetPasswordRequested>(_onResetPasswordRequested);
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

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    debugPrint('AUTH AppStarted ts=$timestamp failedLogin=$_hasRecentFailedLogin');

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
      debugPrint('AUTH AppStarted tokenPresent=${token != null}');

      if (token != null) {
        try {
          final user = await authRepository.getUserInfo(token);
          if (user != null) {
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
      debugPrint('AUTH AppStarted error $e $st');
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

      if (loginResponse != null && loginResponse.token != null) {
        await secureStorage.write(key: 'token', value: loginResponse.token!);
        await secureStorage.write(key: 'login', value: event.login);

        final user = await authRepository.getUserInfo(loginResponse.token!);

        if (user != null) {
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
        emit(const AuthFailure("Invalid login response"));
      }
    } catch (e) {
      final errorMsg = _extractErrorMessage(e);
      final existingToken = await secureStorage.read(key: 'token');
      final hasExistingToken = existingToken != null && existingToken.isNotEmpty;
      if (!hasExistingToken) {
        debugPrint('AUTH LoginFailed fresh attempt (no prior token)');
      }
      _hasRecentFailedLogin = true;
      emit(AuthFailure(errorMsg));
    }
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

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    debugPrint('📊   🚪 LOGOUT REQUESTED - Clearing all user data');
    
    // Clear ALL user-related keys from secure storage (preserve app-level settings like onboarding_completed)
    // This ensures onboarding flag persists through logout but is cleared on app uninstall
    await secureStorage.delete(key: 'token');
    await secureStorage.delete(key: 'login');
    // Note: 'onboarding_completed' is intentionally NOT deleted (app-level setting)
    
    debugPrint('📊   🗑️ Deleted token and login from secure storage');
    debugPrint('📊   ✅ User data cleared - emitting AuthUnauthenticated');
    
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
      emit(AuthFailure(_extractErrorMessage(e)));
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
    debugPrint('🔵 BLOC: CreatePasswordRequested - Starting');
    emit(AuthLoading());

    try {
      if (event.password != event.confirmPassword) {
        debugPrint('❌ BLOC: Passwords do not match');
        emit(const AuthFailure('Passwords do not match'));
        return;
      }

      // Password must be exactly 6 digits (numeric only) for mobile
      if (event.password.length != 6) {
        debugPrint('❌ BLOC: Password must be 6 digits');
        emit(const AuthFailure('Password must be exactly 6 digits'));
        return;
      }

      // Check if password is numeric only
      if (!RegExp(r'^[0-9]+$').hasMatch(event.password)) {
        debugPrint('❌ BLOC: Password must be numeric only');
        emit(const AuthFailure('Password must contain only numbers'));
        return;
      }

      // Check if password is all the same character (brute force prevention)
      final firstChar = event.password[0];
      if (event.password.split('').every((char) => char == firstChar)) {
        debugPrint('❌ BLOC: Password cannot be all the same digit');
        emit(const AuthFailure('Password cannot be all the same digit. Please use a mix of different numbers.'));
        return;
      }

      developer.log('🔵 BLOC: Calling authRepository.createPassword', name: 'AuthBloc');
      appLog('BLOC: Calling createPassword', 'UserId: ${event.userId}');
      debugPrint('🔵 BLOC: Calling authRepository.createPassword');
      final loginResponse = await authRepository.createPassword(
        event.userId,
        event.password,
      );

      developer.log('🔵 BLOC: createPassword returned', name: 'AuthBloc');
      developer.log('🔵 BLOC: loginResponse is null: ${loginResponse == null}', name: 'AuthBloc');
      appLog('BLOC: createPassword returned', 'loginResponse is null: ${loginResponse == null}');
      debugPrint('🔵 BLOC: createPassword returned');
      debugPrint('🔵 BLOC: loginResponse is null: ${loginResponse == null}');
      if (loginResponse != null) {
        debugPrint('🔵 BLOC: loginResponse.token is null: ${loginResponse.token == null}');
        if (loginResponse.token != null) {
          debugPrint('🔵 BLOC: Token found, saving and authenticating');
        }
      }

      if (loginResponse?.token != null) {
        // Token was returned, save it and authenticate
        final token = loginResponse!.token!;
        debugPrint('🔵 BLOC: Saving token to secure storage');
        await secureStorage.write(key: 'token', value: token);
        
        debugPrint('🔵 BLOC: Updating DioClient with new token');
        authRepository.updateToken(token);
        
        debugPrint('🔵 BLOC: Fetching user info');
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
            debugPrint('✅ BLOC: User info fetched, emitting success');
            emit(CreatePasswordSuccess(token: token));
            emit(AuthAuthenticated(
              userId: user.id,
              login: loginToStore.isNotEmpty ? loginToStore : user.login.trim(),
              user: user,
              sessionGeneration: ++_loginSessionGeneration,
            ));
          } else {
            debugPrint('⚠️ BLOC: User info is null, but password was set');
            final fallbackLogin = event.contact?.trim() ?? '';
            if (fallbackLogin.isNotEmpty) {
              await secureStorage.write(key: 'login', value: fallbackLogin);
            }
            // Password was set, but couldn't get user info - still success
            emit(CreatePasswordSuccess(token: token));
          }
        } catch (userInfoError) {
          debugPrint('❌ BLOC: Error fetching user info: $userInfoError');
          debugPrint('❌ BLOC: Error type: ${userInfoError.runtimeType}');
          final fallbackLogin = event.contact?.trim() ?? '';
          if (fallbackLogin.isNotEmpty) {
            await secureStorage.write(key: 'login', value: fallbackLogin);
          }
          // Password was set successfully, but user info fetch failed
          // Still emit success since password creation worked
          emit(CreatePasswordSuccess(token: token));
        }
      } else {
        debugPrint('⚠️ BLOC: No token returned, will login separately');
        // No token returned, need to login after password creation
        emit(CreatePasswordSuccess(token: null));
      }
    } catch (e, stackTrace) {
      developer.log('❌ BLOC: Error in _onCreatePasswordRequested', name: 'AuthBloc', error: e, stackTrace: stackTrace);
      developer.log('❌ BLOC: Error: $e', name: 'AuthBloc');
      developer.log('❌ BLOC: Error Type: ${e.runtimeType}', name: 'AuthBloc');
      appLog('BLOC: Error in createPassword', 'Error: $e, Type: ${e.runtimeType}');
      debugPrint('❌ BLOC: Error in _onCreatePasswordRequested');
      debugPrint('❌ BLOC: Error: $e');
      debugPrint('❌ BLOC: Error Type: ${e.runtimeType}');
      debugPrint('❌ BLOC: Stack Trace: $stackTrace');
      final errorMessage = _extractErrorMessage(e);
      developer.log('❌ BLOC: Extracted error message: $errorMessage', name: 'AuthBloc');
      appLog('BLOC: Extracted error message', errorMessage);
      debugPrint('❌ BLOC: Extracted error message: $errorMessage');
      emit(AuthFailure(errorMessage));
    }
  }

  Future<void> _onResetPasswordRequested(
    ResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      debugPrint('🔵 BLOC: Resetting password for: ${event.login}');
      debugPrint('🔵 BLOC: Password length: ${event.newPassword.length}');
      
      // Reset password via API
      final success = await authRepository.resetPassword(
        event.login,
        event.newPassword,
        event.pin,
      );

      debugPrint('🔵 BLOC: Reset password API returned: $success');

      if (success) {
        debugPrint('✅ BLOC: Password reset successful, now logging in...');
        
        // After successful password reset, automatically log the user in
        final loginResponse = await authRepository.login(
          event.login,
          event.newPassword,
        );

        if (loginResponse != null && loginResponse.token != null) {
          await secureStorage.write(key: 'token', value: loginResponse.token!);
          
          // Store login for reference (password hash not stored for security)
          await secureStorage.write(key: 'login', value: event.login);

          final user = await authRepository.getUserInfo(loginResponse.token!);

          if (user != null) {
            debugPrint('✅ BLOC: User authenticated after password reset');
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
          // Password reset successful but login failed
          emit(ResetPasswordSuccess());
          emit(const AuthFailure("Password reset successful, but login failed. Please try logging in manually."));
        }
      } else {
        emit(const AuthFailure("Failed to reset password. Please try again."));
      }
    } catch (e) {
      debugPrint('❌ BLOC: Error in reset password: $e');
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }
}
