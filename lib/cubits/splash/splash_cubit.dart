import 'package:communal_mobile/core/constants/constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/cubits/settings/settings_cubit.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';
import 'package:communal_mobile/data/models/settings_model.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:dio/dio.dart' show DioException;
import 'splash_state.dart';

class SplashCubit extends Cubit<SplashState> {
  final SharedPreferences prefs;
  final FlutterSecureStorage secureStorage;
  final DioClient dioClient;
  final SettingsCubit settingsCubit;
  final ConnectivityCubit connectivityCubit;
  final AuthRepository authRepository;

  SplashCubit(
    this.prefs,
    this.secureStorage,
    this.dioClient,
    this.settingsCubit,
    this.connectivityCubit,
    this.authRepository,
  ) : super(SplashInitial());

  Future<void> initApp() async {
    emit(SplashLoading());

    try {
      // Wait for connectivity if offline (NetworkInterceptor will handle this for API calls)
      // But we still check here for initial state
      if (!connectivityCubit.isConnected) {
        final connectivity = await Connectivity().checkConnectivity();
        final hasConnection = connectivity.any(
          (result) => result == ConnectivityResult.mobile ||
              result == ConnectivityResult.wifi ||
              result == ConnectivityResult.ethernet,
        );

        if (!hasConnection) {
          emit(SplashNoInternet());
          // Wait for connection to be restored
          await connectivityCubit.waitForConnection();
        }
      }

      // Check if onboarding has been completed (same storage instance as the rest of the app)
      final onboardingCompleted = await secureStorage.read(key: 'onboarding_completed');
      final isFirstTime = onboardingCompleted != 'true'; // First time if onboarding not completed
      print('🔵 SPLASH - isFirstTime: $isFirstTime (onboarding_completed: $onboardingCompleted)');
      
      // Check secure storage for token (same as AuthBloc uses)
      final token = await secureStorage.read(key: 'token');
      print('🔵 SPLASH - Token exists: ${token != null && token.isNotEmpty}');

      // NetworkInterceptor will wait for connectivity if offline
      final response = await dioClient.get(AppConstants.configUri);
      final settings = response.data;
      final settingsResponse = SettingsResponse.fromJson(settings);
      final settingsMap = settingsResponse.asMap();
      settingsCubit.setSettings(settingsMap);
      
      // Priority: 1. First time user -> onboarding, 2. Has valid token -> welcome-back, 3. No token -> welcome
      if (isFirstTime) {
        print('🔵 SPLASH - Emitting SplashFirstTimeUser');
        emit(SplashFirstTimeUser());
      } else if (token != null && token.isNotEmpty) {
        // Token exists, verify it's valid
        // Verify token is valid by fetching user info (same as AuthBloc does)
        print('🔵 SPLASH - Verifying token by fetching user info...');
        try {
          final user = await authRepository.getUserInfo(token);
          if (user != null) {
            // Token is valid, user is authenticated
            print('🔵 SPLASH - User verified, emitting SplashLoggedIn');
            emit(SplashLoggedIn(settingsMap));
          } else {
            // Token exists but is invalid
            print('🔵 SPLASH - User is null, emitting SplashLoggedOut');
            emit(SplashLoggedOut());
          }
        } on DioException catch (e) {
          // Check if it's an authentication error (401/403)
          final statusCode = e.response?.statusCode;
          print('🔵 SPLASH - DioException verifying token: $statusCode - ${e.message}');
          if (statusCode == 401 || statusCode == 403) {
            // Token is invalid or expired
            print('🔵 SPLASH - Authentication failed, emitting SplashLoggedOut');
            emit(SplashLoggedOut());
          } else {
            // Network or other error - assume token is valid but network issue
            // Still navigate to home since we have a token
            print('🔵 SPLASH - Network error but token exists, emitting SplashLoggedIn');
            emit(SplashLoggedIn(settingsMap));
          }
        } catch (e) {
          // Other errors - assume token is valid but couldn't verify
          // Still navigate to welcome-back so user can authenticate
          print('🔵 SPLASH - Error verifying token (non-auth): $e');
          print('🔵 SPLASH - Token exists but could not verify, emitting SplashLoggedIn');
          emit(SplashLoggedIn(settingsMap));
        }
      } else {
        // No token, user is logged out
        print('🔵 SPLASH - No token, emitting SplashLoggedOut');
        emit(SplashLoggedOut());
      }
    } catch (e) {
      print('❌ SPLASH - Top-level error: $e');
      // On error, check if we have a token - if yes, try to navigate to welcome-back
      // If no token, show error
      try {
        final token = await secureStorage.read(key: 'token');
        if (token != null && token.isNotEmpty) {
          print('🔵 SPLASH - Error occurred but token exists, emitting SplashLoggedIn');
          emit(SplashLoggedIn({})); // Empty settings map on error
        } else {
          emit(SplashError("Something went wrong: ${e.toString()}"));
        }
      } catch (storageError) {
        print('❌ SPLASH - Error reading token from storage: $storageError');
        emit(SplashError("Something went wrong: ${e.toString()}"));
      }
    }
  }
}
