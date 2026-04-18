import 'dart:developer' as developer;
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/app_logger.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
    debugPrint('📊 [$timestamp] 🔐 AUTH BLOC - AppStarted event received');
    debugPrint('📊   _hasRecentFailedLogin: $_hasRecentFailedLogin');
    
    // CRITICAL: If we just had a failed login, don't unlock with cached token
    // User must enter password to unlock - no shortcuts
    if (_hasRecentFailedLogin) {
      debugPrint('📊   ⚠️ Recent failed login detected - NOT unlocking with cached token');
      debugPrint('📊   ⚠️ User must enter password to unlock');
      // Clear the flag after a delay to allow for password entry
      Future.delayed(const Duration(seconds: 5), () {
        _hasRecentFailedLogin = false;
      });
      emit(AuthUnauthenticated());
      return;
    }
    
    emit(AuthLoading());

    final token = await secureStorage.read(key: 'token');
    debugPrint('📊   Token exists: ${token != null}');

    if (token != null) {
      // CRITICAL: Validate token with backend - don't trust cached token
      // This ensures that if password was changed, old tokens are invalidated
      try {
        final user = await authRepository.getUserInfo(token);
        if (user != null) {
          final timestamp2 = DateTime.now().millisecondsSinceEpoch;
          debugPrint('📊 [$timestamp2] 🔐 AUTH BLOC - Emitting AuthAuthenticated (from AppStarted)');
          debugPrint('📊   ✅ Token validated with backend - user authenticated');
          final storedLogin = (await secureStorage.read(key: 'login'))?.trim() ?? '';
          final sessionLogin =
              storedLogin.isNotEmpty ? storedLogin : user.login.trim();
          debugPrint('📊   User ID: ${user.id}, Session login: $sessionLogin');
          emit(AuthAuthenticated(
            userId: user.id,
            login: sessionLogin,
            user: user,
            sessionGeneration: 0,
          ));
        } else {
          debugPrint('📊   ❌ Token exists but getUserInfo returned null - token invalid');
          // Token exists but is invalid - clear it
          // IMPORTANT: Keep login - user needs it to unlock the app
          await secureStorage.delete(key: 'token');
          // DO NOT delete login - user needs it to unlock with PIN
          emit(AuthUnauthenticated());
        }
      } catch (e) {
        debugPrint('📊   ❌ Token validation failed: $e');
        // Token validation failed - clear it
        // IMPORTANT: Keep login - user needs it to unlock the app
        await secureStorage.delete(key: 'token');
        // DO NOT delete login - user needs it to unlock with PIN
        emit(AuthUnauthenticated());
      }
    } else {
      debugPrint('📊   No token found - user not authenticated');
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    debugPrint('📊 [$timestamp] 🔐 AUTH BLOC - LoginRequested received');
    debugPrint('📊   Login: ${event.login}');
    debugPrint('📊   Sending password to backend for validation...');
    emit(AuthVerifyingCredentials(++_credentialVerifyAttemptId));

    try {
      final loginResponse = await authRepository.login(
        event.login,
        event.password,
      );

      if (loginResponse != null && loginResponse.token != null) {
        debugPrint('📊   ✅ Backend accepted password - login successful');
        debugPrint('📊   ✅ New token received from backend');
        await secureStorage.write(key: 'token', value: loginResponse.token!);
        
        // Store login for reference (password hash not stored for security)
        await secureStorage.write(key: 'login', value: event.login);

        final user = await authRepository.getUserInfo(loginResponse.token!);

      if (user != null) {
        final timestamp2 = DateTime.now().millisecondsSinceEpoch;
        debugPrint('📊 [$timestamp2] 🔐 AUTH BLOC - Emitting AuthAuthenticated (from LoginRequested)');
        debugPrint('📊   ✅ Password validated by backend - user authenticated');
        debugPrint('📊   ✅ Backend returned 200 OK - password is correct');
        debugPrint('📊   User ID: ${user.id}, Login: ${user.login}');
        
        // CRITICAL: Clear the failed login flag since password was validated successfully
        _hasRecentFailedLogin = false;
        debugPrint('📊   ✅ Cleared _hasRecentFailedLogin flag - password validated successfully');
        
        emit(AuthAuthenticated(
          userId: user.id,
          login: event.login.trim(),
          user: user,
          sessionGeneration: ++_loginSessionGeneration,
        ));
        } else {
          debugPrint('📊   ⚠️ Login successful but could not fetch user info');
          emit(AuthUnauthenticated());
        }
      } else {
        debugPrint('📊   ❌ Backend returned invalid login response');
        emit(const AuthFailure("Invalid login response"));
      }
    } catch (e) {
      final errorMsg = _extractErrorMessage(e);
      debugPrint('📊   ❌ Backend rejected password: $errorMsg');
      debugPrint('📊   ❌ Login failed - password validation failed');
      
      // CRITICAL: Check if token exists - if it does, this is app lock scenario
      // For app lock: Keep token so app shows lock screen on restart (not welcome screen)
      // For fresh login: Token doesn't exist yet, so no need to delete
      final existingToken = await secureStorage.read(key: 'token');
      final hasExistingToken = existingToken != null && existingToken.isNotEmpty;
      
      if (hasExistingToken) {
        // App lock scenario - token exists, user entered wrong PIN
        // CRITICAL: DO NOT delete token - keep it so app shows lock screen on restart
        // This matches first login behavior where wrong password doesn't delete anything
        debugPrint('📊   🔒 App lock scenario - KEEPING token (wrong PIN entered)');
        debugPrint('📊   🔒 Token preserved so app will show lock screen on restart');
      } else {
        // Fresh login scenario - no token exists
        // No token to delete, just mark failed login
        debugPrint('📊   🔐 Fresh login scenario - no token to delete');
      }
      
      // IMPORTANT: Always keep login - user needs it to unlock the app with PIN
      // DO NOT delete login - user needs it to unlock with PIN
      
      // CRITICAL: Mark that we had a failed login
      // This prevents AppStarted from unlocking with a cached token
      _hasRecentFailedLogin = true;
      debugPrint('📊   🚫 Marked _hasRecentFailedLogin = true to prevent cached token unlock');
      
      debugPrint('📊   🚫 Emitting AuthFailure - app MUST stay locked');
      emit(AuthFailure(errorMsg));
    }
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
