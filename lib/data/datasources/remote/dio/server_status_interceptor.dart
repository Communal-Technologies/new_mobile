import 'package:dio/dio.dart';

import 'package:communal_mobile/cubits/server_status/server_status_cubit.dart';

/// Bridges Dio's error stream into [ServerStatusCubit].
///
/// What counts as "the server is the problem":
///   - **No response at all** — `connectionError`, `connectionTimeout`,
///     `sendTimeout`, `receiveTimeout`, or any error where `response`
///     is null. The request never reached a healthy backend.
///   - **5xx** — the request reached us but the backend is unhealthy.
///
/// Anything else (4xx, cancelled requests, badCertificate) is the
/// individual request's problem, not the server's, and is *not* tripped
/// here. Mirrors the dashboard's [axiosConfig] interceptor so both apps
/// agree on the trip / recovery rules.
///
/// Recovery is the [ServerStatusOverlay]'s responsibility — it polls a
/// recovery endpoint via a *separate*, un-intercepted Dio so the ping
/// itself never re-trips the flag it's trying to clear.
class ServerStatusInterceptor extends Interceptor {
  ServerStatusInterceptor(this._cubit);

  final ServerStatusCubit _cubit;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Any successful HTTP transaction proves the path is healthy.
    _cubit.markUp();
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_isServerDown(err)) {
      _cubit.markDown();
    }
    super.onError(err, handler);
  }

  bool _isServerDown(DioException err) {
    // No response → no transport. The server didn't reach us.
    final response = err.response;
    if (response == null) {
      // Cancelled requests are user-driven aborts, not server failures.
      if (err.type == DioExceptionType.cancel) return false;
      // Bad-cert errors mean the network reached a server but TLS
      // failed — still a transport problem from the user's POV; trip.
      return true;
    }

    // Any 5xx status — the backend itself is unhealthy.
    final status = response.statusCode;
    if (status != null && status >= 500 && status < 600) return true;

    return false;
  }
}
