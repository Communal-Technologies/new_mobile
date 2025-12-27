import 'dart:developer' as developer;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/app_logger.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final FlutterSecureStorage secureStorage;

  AuthBloc({required this.authRepository, required this.secureStorage})
    : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
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
    emit(AuthLoading());

    final token = await secureStorage.read(key: 'token');

    if (token != null) {
      final user = await authRepository.getUserInfo(token);
      if (user != null) {
        emit(AuthAuthenticated(userId: user.id, login: user.login));
      } else {
        emit(AuthUnauthenticated());
      }
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final loginResponse = await authRepository.login(
        event.login,
        event.password,
      );

      if (loginResponse != null && loginResponse.token != null) {
        await secureStorage.write(key: 'token', value: loginResponse.token!);
        
        // Store password hash for app lock verification
        final passwordHash = sha256.convert(utf8.encode(event.password)).toString();
        await secureStorage.write(key: 'password_hash', value: passwordHash);
        
        // Store login for reference
        await secureStorage.write(key: 'login', value: event.login);

        final user = await authRepository.getUserInfo(loginResponse.token!);

        if (user != null) {
          emit(AuthAuthenticated(userId: user.id, login: user.login));
        } else {
          emit(AuthUnauthenticated());
        }
      } else {
        emit(const AuthFailure("Invalid login response"));
      }
    } catch (e) {
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Clear only user-related keys from secure storage (preserve app-level settings like onboarding_completed)
    // This ensures onboarding flag persists through logout but is cleared on app uninstall
    await secureStorage.delete(key: 'token');
    await secureStorage.delete(key: 'password_hash');
    await secureStorage.delete(key: 'login');
    // Note: 'onboarding_completed' is intentionally NOT deleted (app-level setting)
    
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
        emit(AuthAuthenticated(userId: user.id, login: user.login));
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
        event.isEmail,
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
    print('🔵 BLOC: CreatePasswordRequested - Starting');
    emit(AuthLoading());

    try {
      if (event.password != event.confirmPassword) {
        print('❌ BLOC: Passwords do not match');
        emit(const AuthFailure('Passwords do not match'));
        return;
      }

      // Password must be exactly 6 digits (numeric only) for mobile
      if (event.password.length != 6) {
        print('❌ BLOC: Password must be 6 digits');
        emit(const AuthFailure('Password must be exactly 6 digits'));
        return;
      }

      // Check if password is numeric only
      if (!RegExp(r'^[0-9]+$').hasMatch(event.password)) {
        print('❌ BLOC: Password must be numeric only');
        emit(const AuthFailure('Password must contain only numbers'));
        return;
      }

      // Check if password is all the same character (brute force prevention)
      final firstChar = event.password[0];
      if (event.password.split('').every((char) => char == firstChar)) {
        print('❌ BLOC: Password cannot be all the same digit');
        emit(const AuthFailure('Password cannot be all the same digit. Please use a mix of different numbers.'));
        return;
      }

      developer.log('🔵 BLOC: Calling authRepository.createPassword', name: 'AuthBloc');
      appLog('BLOC: Calling createPassword', 'UserId: ${event.userId}');
      print('🔵 BLOC: Calling authRepository.createPassword');
      final loginResponse = await authRepository.createPassword(
        event.userId,
        event.password,
      );

      developer.log('🔵 BLOC: createPassword returned', name: 'AuthBloc');
      developer.log('🔵 BLOC: loginResponse is null: ${loginResponse == null}', name: 'AuthBloc');
      appLog('BLOC: createPassword returned', 'loginResponse is null: ${loginResponse == null}');
      print('🔵 BLOC: createPassword returned');
      print('🔵 BLOC: loginResponse is null: ${loginResponse == null}');
      if (loginResponse != null) {
        print('🔵 BLOC: loginResponse.token is null: ${loginResponse.token == null}');
        if (loginResponse.token != null) {
          print('🔵 BLOC: Token found, saving and authenticating');
        }
      }

      if (loginResponse?.token != null) {
        // Token was returned, save it and authenticate
        final token = loginResponse!.token!;
        print('🔵 BLOC: Saving token to secure storage');
        await secureStorage.write(key: 'token', value: token);
        
        print('🔵 BLOC: Updating DioClient with new token');
        authRepository.updateToken(token);
        
        print('🔵 BLOC: Fetching user info');
        try {
          final user = await authRepository.getUserInfo(token);
          if (user != null) {
            print('✅ BLOC: User info fetched, emitting success');
            emit(CreatePasswordSuccess(token: token));
            emit(AuthAuthenticated(userId: user.id, login: user.login));
          } else {
            print('⚠️ BLOC: User info is null, but password was set');
            // Password was set, but couldn't get user info - still success
            emit(CreatePasswordSuccess(token: token));
          }
        } catch (userInfoError) {
          print('❌ BLOC: Error fetching user info: $userInfoError');
          print('❌ BLOC: Error type: ${userInfoError.runtimeType}');
          // Password was set successfully, but user info fetch failed
          // Still emit success since password creation worked
          emit(CreatePasswordSuccess(token: token));
        }
      } else {
        print('⚠️ BLOC: No token returned, will login separately');
        // No token returned, need to login after password creation
        emit(CreatePasswordSuccess(token: null));
      }
    } catch (e, stackTrace) {
      developer.log('❌ BLOC: Error in _onCreatePasswordRequested', name: 'AuthBloc', error: e, stackTrace: stackTrace);
      developer.log('❌ BLOC: Error: $e', name: 'AuthBloc');
      developer.log('❌ BLOC: Error Type: ${e.runtimeType}', name: 'AuthBloc');
      appLog('BLOC: Error in createPassword', 'Error: $e, Type: ${e.runtimeType}');
      print('❌ BLOC: Error in _onCreatePasswordRequested');
      print('❌ BLOC: Error: $e');
      print('❌ BLOC: Error Type: ${e.runtimeType}');
      print('❌ BLOC: Stack Trace: $stackTrace');
      final errorMessage = _extractErrorMessage(e);
      developer.log('❌ BLOC: Extracted error message: $errorMessage', name: 'AuthBloc');
      appLog('BLOC: Extracted error message', errorMessage);
      print('❌ BLOC: Extracted error message: $errorMessage');
      emit(AuthFailure(errorMessage));
    }
  }

  Future<void> _onResetPasswordRequested(
    ResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      print('🔵 BLOC: Resetting password for: ${event.login}');
      print('🔵 BLOC: Password length: ${event.newPassword.length}');
      
      // Reset password via API
      final success = await authRepository.resetPassword(
        event.login,
        event.newPassword,
      );

      print('🔵 BLOC: Reset password API returned: $success');

      if (success) {
        print('✅ BLOC: Password reset successful, now logging in...');
        
        // After successful password reset, automatically log the user in
        final loginResponse = await authRepository.login(
          event.login,
          event.newPassword,
        );

        if (loginResponse != null && loginResponse.token != null) {
          await secureStorage.write(key: 'token', value: loginResponse.token!);
          
          // Store password hash for app lock verification
          final passwordHash = sha256.convert(utf8.encode(event.newPassword)).toString();
          await secureStorage.write(key: 'password_hash', value: passwordHash);
          
          // Store login for reference
          await secureStorage.write(key: 'login', value: event.login);

          final user = await authRepository.getUserInfo(loginResponse.token!);

          if (user != null) {
            print('✅ BLOC: User authenticated after password reset');
            emit(ResetPasswordSuccess());
            emit(AuthAuthenticated(userId: user.id, login: user.login));
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
      print('❌ BLOC: Error in reset password: $e');
      emit(AuthFailure(_extractErrorMessage(e)));
    }
  }
}
