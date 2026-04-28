import 'package:flutter_bloc/flutter_bloc.dart';

/// Whether the *backend* (not the device's network transport) is reachable.
///
/// Distinct from [ConnectivityCubit] (which only knows wifi/cell/ethernet)
/// — a phone with full bars on a dead backend reads as
/// `ConnectivityConnected` but `ServerStatus.down`.
///
/// Flipped by [ServerStatusInterceptor] on any "no response" / 5xx error
/// from a tracked Dio request, and cleared by [ServerStatusOverlay] once
/// its recovery ping returns.
enum ServerStatus { up, down }

class ServerStatusCubit extends Cubit<ServerStatus> {
  ServerStatusCubit() : super(ServerStatus.up);

  void markDown() {
    if (state != ServerStatus.down) emit(ServerStatus.down);
  }

  void markUp() {
    if (state != ServerStatus.up) emit(ServerStatus.up);
  }
}
