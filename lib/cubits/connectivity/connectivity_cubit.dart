import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:communal_mobile/core/constants/constants.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_state.dart';

class ConnectivityCubit extends Cubit<ConnectivityState> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  ConnectivityCubit() : super(ConnectivityInitial()) {
    _init();
  }

  void _init() async {
    final result = await _connectivity.checkConnectivity();
    final hasTransport = result.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet,
    );

    if (hasTransport) {
      _updateConnectivity(result);
    } else if (await _probeInternet()) {
      // OS misreported (common on TECNO/Samsung/Xiaomi OEM ROMs) —
      // device has real internet access despite reporting none.
      _isOffline = false;
      emit(ConnectivityConnected(wasOffline: false));
    }
    // If both the OS check and the probe fail: stay in ConnectivityInitial.
    // isConnected returns true for ConnectivityInitial, so NetworkInterceptor
    // does not block. SplashCubit._waitForNetworkIfNeeded() is the real gate
    // for the offline case — if it passes, the device has connectivity.
    // onConnectivityChanged will push the correct state as the OS catches up.

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectivity,
      onError: (error) {
        _isOffline = true;
        emit(ConnectivityDisconnected());
      },
    );
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final hasConnection = results.any(
      (result) => result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );

    if (hasConnection) {
      final wasOffline = _isOffline;
      _isOffline = false;
      emit(ConnectivityConnected(wasOffline: wasOffline));
    } else {
      _isOffline = true;
      emit(ConnectivityDisconnected());
    }
  }

  /// Probes for real internet connectivity.
  ///
  /// Tries well-known IP addresses first (no DNS lookup required — avoids
  /// DNS resolution failures on certain carriers and OEM ROMs). Falls back
  /// to the API host only if both IP probes fail.
  Future<bool> _probeInternet() async {
    // Cloudflare (1.1.1.1) and Google (8.8.8.8) on port 443 are reachable
    // from virtually any internet connection. Using IPs sidesteps DNS.
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
    // DNS-based fallback — covers cases where well-known IPs are blocked
    // by carrier policy but the API host is still routable.
    try {
      final uri = Uri.tryParse(AppConstants.baseUrl);
      if (uri == null) return false;
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
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

  /// Returns true when connectivity is confirmed or still initialising.
  /// [ConnectivityInitial] is treated as connected so that requests are not
  /// blocked during the brief startup window before [_init] completes its
  /// first [checkConnectivity] call. If the device truly has no network the
  /// actual Dio request will fail with a real error, which is surfaced by the
  /// splash/screen error handlers.
  bool get isConnected =>
      state is ConnectivityConnected || state is ConnectivityInitial;

  Future<bool> waitForConnection({Duration? timeout}) async {
    if (isConnected) return true;

    // State is ConnectivityDisconnected. Poll both the OS and the internet
    // directly so a stale "disconnected" report (OEM ROM bug or a missed
    // onConnectivityChanged event) resolves quickly rather than waiting for
    // a stream event that may never arrive.
    final completer = Completer<bool>();
    StreamSubscription? subscription;
    Timer? timeoutTimer;
    Timer? recheckTimer;

    void cleanUp() {
      // cancel() returns Future<void> — ignore it intentionally so cleanUp
      // can remain synchronous and be called safely from timer callbacks.
      subscription?.cancel().ignore();
      timeoutTimer?.cancel();
      recheckTimer?.cancel();
    }

    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        cleanUp();
        if (!completer.isCompleted) completer.complete(false);
      });
    }

    void doRecheck() async {
      if (completer.isCompleted) return;
      final result = await _connectivity.checkConnectivity();
      final hasTransport = result.any(
        (r) =>
            r == ConnectivityResult.mobile ||
            r == ConnectivityResult.wifi ||
            r == ConnectivityResult.ethernet,
      );
      if (hasTransport) {
        _updateConnectivity(result);
      } else if (!completer.isCompleted && await _probeInternet()) {
        // OS still says no network but probe confirms internet is reachable.
        final wasOffline = _isOffline;
        _isOffline = false;
        emit(ConnectivityConnected(wasOffline: wasOffline));
      }
    }

    // Probe immediately — don't wait 3 s for the first periodic tick.
    doRecheck();

    // Continue rechecking every 3 s so genuine reconnection is detected fast.
    recheckTimer = Timer.periodic(const Duration(seconds: 3), (_) => doRecheck());

    subscription = stream.listen((state) {
      if (state is ConnectivityConnected) {
        cleanUp();
        if (!completer.isCompleted) completer.complete(true);
      }
    });

    return completer.future;
  }

  @override
  Future<void> close() {
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
