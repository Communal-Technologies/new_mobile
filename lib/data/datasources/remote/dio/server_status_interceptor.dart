import 'package:dio/dio.dart';

import 'package:communal_mobile/cubits/server_status/server_status_cubit.dart';

/// Bridges Dio's error stream into [ServerStatusCubit].
///
/// What counts as "the server is the problem":
///   - **No transport at all** — `connectionError` (DNS/refused/no route)
///     or `connectionTimeout` (TCP handshake didn't complete). We never
///     even reached the backend, so the modal is the right UX.
///   - **5xx** — the request reached us but the backend is unhealthy.
///
/// What does NOT trip the modal:
///   - `receiveTimeout` / `sendTimeout` — the request reached the server
///     and is just taking too long. KYC tier-2 (multipart + Anchor
///     verification), statement exports, and obligation submissions can
///     all legitimately run past the receive deadline on slow mobile
///     networks. Tripping the global "Connection lost" modal on every
///     slow one-off request was the historical bug behind the false-
///     positive popups; the screen-level catch shows a per-request
///     "Request timed out" toast instead.
///   - 4xx, cancelled requests — caller's problem, not the server's.
///   - badCertificate — handled by the cert-pinning callback higher up.
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
    final response = err.response;
    if (response == null) {
      // Cancelled requests are user-driven aborts, not server failures.
      if (err.type == DioExceptionType.cancel) return false;
      // Slow per-request response. The TCP / TLS handshake completed
      // and the request actually reached the server — it just hasn't
      // replied within the receive / send deadline. That's per-request
      // slowness (KYC submissions, file uploads, downstream Anchor
      // calls), NOT a server-wide outage. Don't trip the global modal.
      // Caller surfaces a "Request timed out" toast instead.
      if (err.type == DioExceptionType.receiveTimeout) return false;
      if (err.type == DioExceptionType.sendTimeout) return false;
      // No response and not just slow: connectionError / connectionTimeout
      // / unknown SocketException / badCertificate — really cannot reach
      // a healthy backend. Trip.
      return true;
    }

    // Any 5xx status — the backend itself is unhealthy.
    final status = response.statusCode;
    if (status != null && status >= 500 && status < 600) return true;

    return false;
  }
}
