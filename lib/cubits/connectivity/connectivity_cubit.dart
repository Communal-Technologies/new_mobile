import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_state.dart';

class ConnectivityCubit extends Cubit<ConnectivityState> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  ConnectivityCubit() : super(ConnectivityInitial()) {
    _init();
  }

  void _init() async {
    // Check initial connectivity and set state
    final result = await _connectivity.checkConnectivity();
    _updateConnectivity(result);

    // Listen to connectivity changes
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

  bool get isConnected => state is ConnectivityConnected;

  Future<bool> waitForConnection({Duration? timeout}) async {
    if (isConnected) return true;

    final completer = Completer<bool>();
    StreamSubscription? subscription;
    Timer? timeoutTimer;

    if (timeout != null) {
      timeoutTimer = Timer(timeout, () {
        subscription?.cancel();
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      });
    }

    subscription = stream.listen((state) {
      if (state is ConnectivityConnected) {
        subscription?.cancel();
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
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

