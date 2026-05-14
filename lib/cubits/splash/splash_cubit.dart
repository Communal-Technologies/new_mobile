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
import 'package:dio/dio.dart' show DioException;
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

    // Fast path: OS reports a network interface.
    final results = await Connectivity().checkConnectivity();
    if (hasTransport(results)) return;

    // Slow path: connectivity_plus says no network — verify with a real
    // TCP probe before blocking the user on the offline screen.
    if (await _probeServer()) return;

    emit(SplashNoInternet());

    final done = Completer<void>();
    Timer? probeTimer;
    StreamSubscription<List<ConnectivityResult>>? sub;

    void complete() {
      if (!done.isCompleted) done.complete();
    }

    sub = Connectivity().onConnectivityChanged.listen((next) {
      if (isClosed) { complete(); return; }
      if (hasTransport(next)) {
        complete();
      } else {
        emit(SplashNoInternet());
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

  /// TCP-level reachability check for the API host. Returns true as soon
  /// as a connection is established (immediately destroyed — we only need
  /// to know the host is routable, not read any data).
  Future<bool> _probeServer() async {
    try {
      final uri = Uri.tryParse(AppConstants.baseUrl);
      if (uri == null) return false;
      final port = uri.hasPort
          ? uri.port
          : (uri.scheme == 'https' ? 443 : 80);
      final socket = await Socket.connect(
        uri.host,
        port,
        timeout: const Duration(seconds: 4),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
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
      emit(SplashError(dioTransportUserMessage(e)));
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
      emit(SplashError(dioTransportUserMessage(e)));
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
