import 'package:communal_mobile/core/constants/constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/cubits/settings/settings_cubit.dart';
import 'package:communal_mobile/data/models/settings_model.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/data/repositories/regions_repository.dart';
import 'package:dio/dio.dart' show DioException, DioExceptionType;
import 'package:flutter/foundation.dart';
import 'splash_state.dart';

class SplashCubit extends Cubit<SplashState> {
  final SharedPreferences prefs;
  final FlutterSecureStorage secureStorage;
  final DioClient dioClient;
  final SettingsCubit settingsCubit;
  final AuthRepository authRepository;
  final RegionsRepository regionsRepository;

  SplashCubit(
    this.prefs,
    this.secureStorage,
    this.dioClient,
    this.settingsCubit,
    this.authRepository,
    this.regionsRepository,
  ) : super(SplashInitial());

  /// Cold start: wait for network (if needed), load settings + regions, then route.
  /// Does not navigate on API failures — emits [SplashError] with a clear message instead.
  Future<void> initApp() async {
    emit(SplashLoading());

    try {
      await _waitForNetworkIfNeeded();
      // Clear [SplashNoInternet] so the UI shows loading while settings/regions run.
      emit(SplashLoading());

      final onboardingCompleted =
          await secureStorage.read(key: 'onboarding_completed');
      final isFirstTime = onboardingCompleted != 'true';
      final token = await secureStorage.read(key: 'token');

      final settingsMap = await _loadSystemSettingsOrEmitError();
      if (settingsMap == null) return;

      final regionsOk = await _loadRegionsOrEmitError();
      if (!regionsOk) return;

      if (isFirstTime) {
        emit(SplashFirstTimeUser());
        return;
      }

      if (token == null || token.isEmpty) {
        emit(SplashLoggedOut());
        return;
      }

      await _verifyTokenAndEmit(token, settingsMap);
    } catch (e, stackTrace) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('SPLASH - Top-level error: $e\n$stackTrace');
      }
      emit(SplashError('Something went wrong. Please try again.'));
    }
  }

  /// Blocks until the OS reports Wi‑Fi, mobile data, or ethernet.
  ///
  /// Uses [Connectivity] directly so we are not fooled by [ConnectivityCubit]
  /// being briefly out of sync, and we do not continue while the device still
  /// reports [ConnectivityResult.none].
  ///
  /// Stays on [SplashNoInternet] until connectivity returns — no navigation.
  Future<void> _waitForNetworkIfNeeded() async {
    bool hasTransport(List<ConnectivityResult> results) {
      return results.any(
        (result) =>
            result == ConnectivityResult.mobile ||
            result == ConnectivityResult.wifi ||
            result == ConnectivityResult.ethernet,
      );
    }

    var results = await Connectivity().checkConnectivity();
    if (hasTransport(results)) return;

    emit(SplashNoInternet());

    await for (final next in Connectivity().onConnectivityChanged) {
      if (hasTransport(next)) {
        return;
      }
      emit(SplashNoInternet());
    }
  }

  Future<Map<String, dynamic>?> _loadSystemSettingsOrEmitError() async {
    try {
      final response = await dioClient.get(AppConstants.configUri);
      final raw = response.data;
      if (raw is! Map) {
        emit(SplashError('Invalid response from server. Please try again.'));
        return null;
      }
      final settingsResponse =
          SettingsResponse.fromJson(Map<String, dynamic>.from(raw));
      final settingsMap = settingsResponse.asMap();
      settingsCubit.setSettings(settingsMap);
      return settingsMap;
    } on DioException catch (e) {
      emit(SplashError(_dioErrorMessage(e)));
      return null;
    } catch (_) {
      emit(SplashError('Could not load app settings. Please try again.'));
      return null;
    }
  }

  Future<bool> _loadRegionsOrEmitError() async {
    try {
      await regionsRepository.fetchRegions(forceRefresh: true);
      return true;
    } on DioException catch (e) {
      emit(SplashError(_dioErrorMessage(e)));
      return false;
    } catch (_) {
      emit(SplashError('Could not load regions. Please try again.'));
      return false;
    }
  }

  Future<void> _verifyTokenAndEmit(
    String token,
    Map<String, dynamic> settingsMap,
  ) async {
    try {
      final user = await authRepository.getUserInfo(token);
      if (user != null) {
        emit(SplashLoggedIn(settingsMap));
      } else {
        emit(SplashLoggedOut());
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) {
        emit(SplashLoggedOut());
      } else {
        emit(SplashError(_dioErrorMessage(e)));
      }
    } catch (_) {
      emit(
        SplashError(
          'Could not verify your session. Check your connection and try again.',
        ),
      );
    }
  }

  String _dioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Check your connection and try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Check your network and try again.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code != null) {
          return 'Server error ($code). Please try again later.';
        }
        return 'Could not reach the server. Please try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
