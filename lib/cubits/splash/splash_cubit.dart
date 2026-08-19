import 'dart:async';
import 'dart:io';

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
import 'package:communal_mobile/core/utils/app_logger.dart';
import 'package:communal_mobile/core/utils/dio_transport_user_message.dart';
import 'package:dio/dio.dart' show DioException, DioExceptionType;
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
      AppLogger.error('Splash', 'Top-level error',
          error: e, stackTrace: stackTrace);
      emit(SplashError('Something went wrong. Please try again.'));
    }
  }

  /// Blocks until the API server is confirmed reachable via a direct TCP probe.
  ///
  /// Testing general internet connectivity (e.g. probing 1.1.1.1) is not
  /// sufficient — devices can have working internet while the API host is
  /// unreachable due to carrier DNS failures or routing issues. Probing only
  /// the API host means [SplashNoInternet] is shown (with auto-retry) rather
  /// than proceeding to API calls that will fail and landing on the dead-end
  /// [SplashError] screen.
  ///
  /// The probe also handles Android OEM ROMs that misreport
  /// [ConnectivityResult.none] despite having real internet: if the API host
  /// TCP connect succeeds regardless of what the OS reports, we proceed.
  Future<void> _waitForNetworkIfNeeded() async {
    bool hasTransport(List<ConnectivityResult> results) => results.any(
          (r) =>
              r == ConnectivityResult.mobile ||
              r == ConnectivityResult.wifi ||
              r == ConnectivityResult.ethernet,
        );

    // Always probe for real internet access — the OS transport flag alone
    // cannot confirm reachability. Captive-portal WiFi, depleted mobile data,
    // and OEM ROM bugs (Samsung/Xiaomi/Huawei) all pass the transport check
    // while having no actual internet, causing every subsequent API call to
    // fail and landing users on the "We couldn't reach Communal" error screen.
    if (await _probeServer()) return;

    emit(SplashNoInternet());

    final done = Completer<void>();
    Timer? probeTimer;
    StreamSubscription<List<ConnectivityResult>>? sub;

    void complete() {
      if (!done.isCompleted) done.complete();
    }

    sub = Connectivity().onConnectivityChanged.listen((next) async {
      if (isClosed) { complete(); return; }
      if (hasTransport(next)) {
        // Probe immediately when OS reports a transport — prevents captive-portal
        // connections from producing a false "reconnected" signal.
        if (await _probeServer()) complete();
      } else {
        if (!done.isCompleted) emit(SplashNoInternet());
      }
    });

    probeTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (isClosed) { complete(); return; }
      if (await _probeServer()) { complete(); }
    });

    await done.future;
    probeTimer.cancel();
    await sub.cancel();
  }

  /// TCP-level probe against the API host specifically. Returns true only when
  /// the API server is reachable — this is the only check that matters at
  /// splash, since we need the API to be routable from this device.
  ///
  /// Previously this probed well-known IPs (1.1.1.1, 8.8.8.8) first, which
  /// caused false positives: devices where those IPs were reachable (general
  /// internet worked) but the API host had DNS or routing issues would pass
  /// the probe, proceed straight to API calls, fail all 5 retries, and land
  /// on the dead-end "We couldn't reach Communal" error screen. Testing the
  /// API host directly prevents this — if it fails, the splash stays on the
  /// auto-retrying SplashNoInternet screen until the API is reachable.
  Future<bool> _probeServer() async {
    try {
      final uri = Uri.tryParse(AppConstants.baseUrl);
      if (uri == null) {
        AppLogger.warn('SplashCubit', 'Cannot parse baseUrl: ${AppConstants.baseUrl}');
        return false;
      }
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final socket = await Socket.connect(
        uri.host,
        port,
        timeout: const Duration(seconds: 10),
      );
      socket.destroy();
      AppLogger.debug('SplashCubit', 'TCP probe OK → ${uri.host}:$port');
      return true;
    } catch (e) {
      AppLogger.warn('SplashCubit', 'TCP probe failed → ${AppConstants.baseUrl}', error: e);
      return false;
    }
  }

  /// Returns true when a [DioException] represents a transient server-side
  /// failure that is safe to retry (5xx gateway/overload errors and transport
  /// timeouts). Client errors (4xx) and cancellations are not retried.
  static bool _isRetryable(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        // 500 Internal Server Error, 502 Bad Gateway, 503 Service Unavailable,
        // 504 Gateway Timeout — all transient; 4xx are caller errors, don't retry.
        return code != null && code >= 500;
      default:
        return false;
    }
  }

  Future<Map<String, dynamic>?> _loadSystemSettingsOrEmitError() async {
    const maxAttempts = 5;
    DioException? lastDioError;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        // Exponential back-off: 2 s, 4 s, 8 s, 16 s — gives the upstream
        // time to recover from transient overload (502/503) before retrying.
        await Future.delayed(Duration(seconds: 2 << (attempt - 1)));
      }
      try {
        final response = await dioClient.get(AppConstants.configUri);
        final raw = response.data;
        if (raw is! Map) {
          AppLogger.warn('SplashCubit', 'Settings: unexpected response type ${raw.runtimeType}');
          emit(SplashError('Invalid response from server. Please try again.'));
          return null;
        }
        final settingsResponse =
            SettingsResponse.fromJson(Map<String, dynamic>.from(raw));
        final settingsMap = settingsResponse.asMap();
        settingsCubit.setSettings(settingsMap);
        return settingsMap;
      } on DioException catch (e) {
        lastDioError = e;
        AppLogger.warn(
          'SplashCubit',
          'Settings attempt ${attempt + 1}/$maxAttempts failed '
          '(type=${e.type.name}, status=${e.response?.statusCode}, '
          'error=${e.error.runtimeType}): ${e.message}',
        );
        if (_isRetryable(e) && attempt < maxAttempts - 1) continue;
        emit(SplashError(dioTransportUserMessage(e)));
        return null;
      } catch (e, st) {
        AppLogger.error('SplashCubit', 'Settings: unexpected error', error: e, stackTrace: st);
        settingsCubit.setSettings(const <String, dynamic>{});
        return const <String, dynamic>{};
      }
    }

    // All retries exhausted.
    AppLogger.warn('SplashCubit', 'Settings: all $maxAttempts attempts failed');
    emit(SplashError(lastDioError != null
        ? dioTransportUserMessage(lastDioError)
        : 'Could not load app settings. Please try again.'));
    return null;
  }

  Future<bool> _loadRegionsOrEmitError() async {
    const maxAttempts = 5;
    DioException? lastDioError;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(seconds: 2 << (attempt - 1)));
      }
      try {
        await regionsRepository.fetchRegions(forceRefresh: true);
        return true;
      } on DioException catch (e) {
        lastDioError = e;
        AppLogger.warn(
          'SplashCubit',
          'Regions attempt ${attempt + 1}/$maxAttempts failed '
          '(type=${e.type.name}, status=${e.response?.statusCode}, '
          'error=${e.error.runtimeType}): ${e.message}',
        );
        if (_isRetryable(e) && attempt < maxAttempts - 1) continue;
        emit(SplashError(dioTransportUserMessage(e)));
        return false;
      } catch (e, st) {
        AppLogger.error('SplashCubit', 'Regions: unexpected error', error: e, stackTrace: st);
        emit(SplashError('Could not load regions. Please try again.'));
        return false;
      }
    }

    AppLogger.warn('SplashCubit', 'Regions: all $maxAttempts attempts failed');
    emit(SplashError(lastDioError != null
        ? dioTransportUserMessage(lastDioError)
        : 'Could not load regions. Please try again.'));
    return false;
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
        emit(SplashError(dioTransportUserMessage(e)));
      }
    } catch (_) {
      emit(
        SplashError(
          'Could not verify your session. Check your connection and try again.',
        ),
      );
    }
  }
}
