import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import 'package:communal_mobile/core/security/session_invalidation_notifier.dart';
import 'package:communal_mobile/core/security/token_manager.dart';
import 'package:communal_mobile/core/utils/app_logger.dart';
import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';

/// Pre-request and on-401 token refresh for the dio HTTP client (audit M6).
///
/// Pre-request flow (`onRequest`)
/// ------------------------------
/// - If [TokenManager.shouldRefreshSoon] reports the access token will
///   expire within the configured lead time, we run a refresh **before**
///   firing the user's request. The new access token is then attached to
///   the outbound headers. Avoids the 401→refresh→retry round trip on the
///   happy path.
/// - If [TokenManager.canRefresh] is false (legacy install with no refresh
///   token), the interceptor is a no-op and the request goes out unchanged
///   — falling through to the existing 401 → AuthUnauthenticated flow.
///
/// On-401 flow (`onError`)
/// -----------------------
/// - If the failed request was already an attempt at refreshing, we surface
///   the error and clear tokens so the bloc can emit AuthUnauthenticated.
/// - If we have a refresh token, fire one refresh, retry the original
///   request once with the new access token, and pass that response back to
///   the caller. The user never sees the 401.
/// - Concurrent 401s share the same in-flight refresh via [_refreshing] —
///   the first request triggers it, the others await the same Future and
///   re-issue with the new token. Avoids a thundering-herd refresh storm.
///
/// What this does NOT do
/// ---------------------
/// - The refresh call itself uses a **bare** `Dio()` so it can't recurse
///   into this interceptor. The bare client also intentionally does not
///   route through the cert-pinning / network / logging interceptors —
///   that's a deliberate trade-off for simplicity; the call still hits
///   the same baseUrl over HTTPS.
/// - Cookie-based refresh (the SPA's `communal_rt` cookie) is the
///   backend's other path. Mobile is bearer-only, so we always send the
///   refresh token in the body.
@lazySingleton
class RefreshTokenInterceptor extends Interceptor {
  RefreshTokenInterceptor(this._tokens, this._dio);

  final TokenManager _tokens;

  /// The same dio instance this interceptor is registered on. Used for
  /// (a) one-shot retry of a 401'd request — `dio.fetch(retryOptions)`
  /// sees the `_retryMarker` and bails out of the on-401 path so we don't
  /// loop, and (b) updating `dio.options.headers[Authorization]` after a
  /// successful refresh so subsequent fresh requests don't carry the
  /// stale default token.
  final Dio _dio;

  /// In-flight refresh shared by all concurrent 401 retries. Cleared in a
  /// `finally` so a failed refresh doesn't permanently block subsequent
  /// retries.
  Future<String?>? _refreshing;

  /// Custom marker we add to retried requests so the on-401 path won't
  /// recurse into a second refresh attempt for the same logical request.
  static const String _retryMarker = 'x-tm-retry';

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip the refresh-token endpoint itself — refreshing in `onRequest`
    // for /refresh-token would deadlock.
    if (_isRefreshEndpoint(options)) {
      return handler.next(options);
    }

    if (!_tokens.canRefresh || !_tokens.shouldRefreshSoon()) {
      return handler.next(options);
    }

    try {
      final newAccess = await _ensureRefresh();
      if (newAccess != null) {
        options.headers[HttpHeaders.authorizationHeader] = 'Bearer $newAccess';
      }
    } catch (e) {
      AppLogger.warn('RefreshInterceptor', 'pre-request refresh failed: $e');
      // Fall through: the request goes out with the (potentially expired)
      // token; the 401 handler will deal with it.
    }
    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    if (response?.statusCode != 401) return handler.next(err);
    final original = err.requestOptions;
    if (_isRefreshEndpoint(original)) {
      // The refresh call itself was rejected — the session is dead. Clear
      // tokens and let the bloc/UI react to AuthUnauthenticated.
      await _tokens.clear();
      markSessionInvalidated('Your session has expired. Please sign in again.');
      return handler.next(err);
    }
    if (original.extra[_retryMarker] == true) {
      // Already retried once — don't loop.
      return handler.next(err);
    }
    if (!_tokens.canRefresh) {
      return handler.next(err);
    }

    try {
      final newAccess = await _ensureRefresh();
      if (newAccess == null) {
        return handler.next(err);
      }
      // Retry once with the new access token, on the same dio so TLS
      // pinning / connectivity checks still apply. The `_retryMarker`
      // flag short-circuits the on-401 path on this retry to avoid loops.
      final retryOptions = original
        ..headers[HttpHeaders.authorizationHeader] = 'Bearer $newAccess'
        ..extra[_retryMarker] = true;
      final retryResponse = await _dio.fetch(retryOptions);
      return handler.resolve(retryResponse);
    } catch (e) {
      AppLogger.warn('RefreshInterceptor', 'reactive refresh failed: $e');
      return handler.next(err);
    }
  }

  /// Fires a single refresh call that all concurrent waiters share.
  Future<String?> _ensureRefresh() async {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;

    final completer = Completer<String?>();
    _refreshing = completer.future;
    try {
      final newAccess = await _doRefresh();
      completer.complete(newAccess);
      return newAccess;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _refreshing = null;
    }
  }

  Future<String?> _doRefresh() async {
    final refresh = _tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) return null;

    // Deliberately bare — see class doc-block. Reuses the same baseUrl
    // and content-type as the main dio.
    final bare = Dio(BaseOptions(
      baseUrl: _dio.options.baseUrl,
      headers: {
        HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
      },
    ));
    final response = await bare.post(
      ApiEndpoints.refreshToken,
      data: {'refresh_token': refresh},
    );
    final data = response.data;
    if (data is! Map) return null;
    final access = data['token']?.toString();
    final newRefresh = data['refresh_token']?.toString();
    final expiresIn = (data['expires_in'] as num?)?.toInt();
    if (access == null || access.isEmpty) return null;

    await _tokens.updateTokens(
      accessToken: access,
      refreshToken: newRefresh,
      expiresIn: expiresIn,
    );
    // Update the dio default header so subsequent fresh requests don't
    // carry the now-stale token until they hit a 401.
    _dio.options.headers[HttpHeaders.authorizationHeader] = 'Bearer $access';
    return access;
  }

  bool _isRefreshEndpoint(RequestOptions options) {
    final path = options.path;
    return path == ApiEndpoints.refreshToken ||
        path.endsWith(ApiEndpoints.refreshToken);
  }
}
