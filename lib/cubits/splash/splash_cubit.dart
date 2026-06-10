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

  /// Blocks until connectivity is confirmed — either by [Connectivity]
  /// reporting a network interface, or by a successful TCP probe to the
  /// server.
  ///
  /// The TCP probe is the fallback for Android OEM ROMs where
  /// [Connectivity] misreports [ConnectivityResult.none] despite the
  /// device having real internet access (common on certain Samsung /
  /// Xiaomi / Huawei builds). Without the probe those devices were stuck
  /// forever on the no-internet screen even though the browser worked fine.
  ///
  /// While genuinely offline, the probe retries every 5 seconds so
  /// recovery is fast once the network comes back — we don't rely
  /// solely on [onConnectivityChanged] which can be slow or silent on
  /// the same affected devices.
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

  /// TCP-level reachability probe. Returns true as soon as any connection
  /// succeeds — we only need to know internet is available, not read data.
  ///
  /// Tries well-known IPs first (Cloudflare 1.1.1.1, Google 8.8.8.8) to
  /// avoid DNS resolution failures on slow or broken carrier DNS servers
  /// (observed on certain African mobile networks). Falls back to the API
  /// host if those are blocked by carrier policy.
  Future<bool> _probeServer() async {
    for (final ip in const ['1.1.1.1', '8.8.8.8']) {
      try {
        final socket = await Socket.connect(
          ip,
          443,
          timeout: const Duration(seconds: 4),
        );
        socket.destroy();
        return true;
      } catch (_) {}
    }
    try {
      final uri = Uri.tryParse(AppConstants.baseUrl);
      if (uri == null) return false;
      final port = uri.hasPort
          ? uri.port
          : (uri.scheme == 'https' ? 443 : 80);
      final socket = await Socket.connect(
        uri.host,
        port,
        timeout: const Duration(seconds: 8),
      );
      socket.destroy();
      return true;
    } catch (_) {
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
        if (_isRetryable(e) && attempt < maxAttempts - 1) continue;
        emit(SplashError(dioTransportUserMessage(e)));
        return null;
      } catch (_) {
        emit(SplashError('Could not load app settings. Please try again.'));
        return null;
      }
    }

    // All retries exhausted.
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
        if (_isRetryable(e) && attempt < maxAttempts - 1) continue;
        emit(SplashError(dioTransportUserMessage(e)));
        return false;
      } catch (_) {
        emit(SplashError('Could not load regions. Please try again.'));
        return false;
      }
    }

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
