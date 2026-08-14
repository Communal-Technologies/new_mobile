import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:communal_mobile/data/datasources/remote/dio/cert_pinning.dart';
import 'package:communal_mobile/data/datasources/remote/dio/logging_interceptor.dart';
import 'package:communal_mobile/data/datasources/remote/dio/network_interceptor.dart';
import 'package:communal_mobile/data/datasources/remote/dio/refresh_token_interceptor.dart';
import 'package:communal_mobile/core/constants/constants.dart';
import 'package:communal_mobile/core/security/session_invalidation_notifier.dart';
import 'package:communal_mobile/core/utils/app_logger.dart';

class DioClient {
  final String baseUrl;
  final LoggingInterceptor loggingInterceptor;
  final NetworkInterceptor? networkInterceptor;
  final RefreshTokenInterceptor? refreshTokenInterceptor;

  Dio dio = Dio();
  String? _token;

  DioClient(
    this.baseUrl, {
    required this.loggingInterceptor,
    this.networkInterceptor,
    this.refreshTokenInterceptor,
    Dio? customDio,
    String? token, // Inject the token externally (from BLoC or secure storage)
  }) {
    dio = customDio ?? Dio();
    _token = token;
    _init();
  }

  void _init() {
    dio
      ..options.baseUrl = baseUrl
      ..options.connectTimeout = const Duration(seconds: 30)
      // 60s, not 30s. KYC tier-2 (multipart upload + Anchor verification
      // round-trip) and statement export routinely run 20–40s on weaker
      // mobile links. With the previous 30s deadline, those completed-
      // but-slow requests timed out from Dio's perspective, the
      // interceptor saw `response == null`, and the global "Connection
      // lost" modal popped on every slow KYC submission. The receive
      // deadline is the wrong layer to enforce per-request budgets.
      ..options.receiveTimeout = const Duration(seconds: 60)
      ..options.headers = {
        HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
        // Only include the Authorization header when a token is available.
        // Sending `Authorization: ` (empty bearer) causes nginx/PHP-FPM to
        // try to parse the malformed token — which can stall and return 502
        // on slow upstream connections even when the route is public.
        if (_token != null && _token!.isNotEmpty)
          HttpHeaders.authorizationHeader: 'Bearer $_token',
        'X-localization': AppConstants.defaultLanguage,
        // Tell any intermediate proxy (CDN, Nginx cache) not to serve a
        // cached response for this request. Paired with the backend's
        // Cache-Control: no-store response header to prevent the "wrong
        // user on welcome screen after app update" caching bug.
        HttpHeaders.cacheControlHeader: 'no-cache',
        HttpHeaders.userAgentHeader:
            'CommunalApp/1.0 (${Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iOS' : Platform.operatingSystem})',
      };

    // Audit M8: SPKI cert-pin override for the dio HTTP client. Adds a
    // post-validation check on cert errors that accepts only pinned certs
    // for a configured host, rejecting MITM attempts via rogue / locally-
    // installed CAs. When CertPinning.pinsByHost is empty (the shipping
    // default until real pins are generated), the callback returns false so
    // behaviour matches the platform default.
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => HttpClient()
        ..badCertificateCallback = (cert, host, port) {
          if (!CertPinning.isPinned(host)) {
            // No pins configured → don't override the default-trust failure.
            return false;
          }
          return CertPinning.verify(cert, host);
        },
    );

    final isDebug = AppConstants.appEnvironment == 'development';

    // Add network interceptor first (so it can wait for connectivity)
    if (networkInterceptor != null) {
      dio.interceptors.insert(0, networkInterceptor!);
    }

    // Refresh interceptor (audit M6): proactive + reactive token refresh.
    // Sits *after* the network interceptor (so we don't try to refresh
    // before connectivity is restored) and *before* the logger (so the
    // refreshed Authorization header is what gets logged in dev).
    if (refreshTokenInterceptor != null) {
      dio.interceptors.add(refreshTokenInterceptor!);
    }
    // Only add logger in dev
    if (isDebug) {
      dio.interceptors.add(loggingInterceptor);
    }
  }

  void updateToken(String token) {
    _token = token;
    dio.options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
  }

  /// Removes the default Authorization header so a logged-out (or switched-out)
  /// user's bearer can't linger on the in-memory dio instance across a hot
  /// reload. Pairs with [TokenManager.clear].
  void clearToken() {
    _token = null;
    dio.options.headers.remove(HttpHeaders.authorizationHeader);
  }

  void updateUserAgent(String deviceLabel) {
    dio.options.headers[HttpHeaders.userAgentHeader] =
        'CommunalApp/1.0 ($deviceLabel)';
  }

  /// Sends the install's stable device id on every request as `X-Device-Id`,
  /// so the backend audit log can record `device` on all flows (not only
  /// biometric-signed ones, which carry X-Biometric-Device-Id).
  void setDeviceId(String deviceId) {
    dio.options.headers['X-Device-Id'] = deviceId;
  }

  void _handleUnauthorizedResponse(DioException error, {required bool requireAuth}) {
    if (!requireAuth) return;
    final code = error.response?.statusCode;
    if (code != 401) return;

    final data = error.response?.data;
    String? backendMessage;
    if (data is Map) {
      backendMessage = data['message']?.toString();
    } else if (data is String) {
      backendMessage = data;
    }

    markSessionInvalidated(backendMessage);
  }

  Future<Response> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    bool requireAuth = true,
    // When true the refresh interceptor will NOT proactively refresh before
    // this request. Used by the app-start identity check so the logged-in user
    // is resolved from the current access token, not swapped by a refresh.
    bool skipProactiveRefresh = false,
  }) async {
    final extra =
        skipProactiveRefresh ? <String, dynamic>{'skipProactiveRefresh': true} : null;
    try {
      return await dio.get(
        uri,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        options: requireAuth
            ? (extra == null ? null : Options(extra: extra))
            : Options(
                extra: extra,
                headers: {
                  HttpHeaders.contentTypeHeader:
                      'application/json; charset=UTF-8',
                  'X-localization': AppConstants.defaultLanguage,
                },
              ),
      );
    } on DioException catch (e) {
      _handleUnauthorizedResponse(e, requireAuth: requireAuth);
      rethrow;
    } on SocketException {
      throw const SocketException('No Internet connection');
    } on FormatException {
      throw const FormatException("Unable to process the data");
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> post(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    bool requireAuth = true,
    String? idempotencyKey,
    Map<String, String>? extraHeaders,
  }) async {
    try {
      final options = Options();
      if (!requireAuth) {
        // Public endpoint — strip the Authorization header.
        options.headers = {
          HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
          'X-localization': AppConstants.defaultLanguage,
        };
      }
      // Audit M23: caller-supplied Idempotency-Key threads to the backend so
      // a network drop + retry on a non-idempotent operation (transfer, loan,
      // KYC submission) dedupes server-side instead of double-processing.
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
        final headers = options.headers ?? <String, dynamic>{};
        headers['Idempotency-Key'] = idempotencyKey;
        options.headers = headers;
      }
      // Audit M38: biometric signature triple (X-Biometric-{Device-Id,
      // Nonce-Id, Signature}) lives in [extraHeaders] when the caller is
      // a biometric-gated endpoint (transfer, pay-obligation). Generic
      // mechanism so future per-request headers don't need a new param.
      if (extraHeaders != null && extraHeaders.isNotEmpty) {
        final headers = options.headers ?? <String, dynamic>{};
        headers.addAll(extraHeaders);
        options.headers = headers;
      }
      return await dio.post(
        uri,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        options: options,
      );
    } on DioException catch (e) {
      _handleUnauthorizedResponse(e, requireAuth: requireAuth);
      AppLogger.warn(
        'DioClient',
        'POST $uri failed (${e.type.name}, status=${e.response?.statusCode})',
      );
      rethrow;
    } on FormatException {
      throw const FormatException("Unable to process the data");
    } catch (e, stackTrace) {
      AppLogger.error('DioClient', 'POST $uri unexpected error',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// POST `multipart/form-data` (e.g. KYC tier-2). Does not force JSON content-type.
  Future<Response> postFormData(
    String uri, {
    required FormData data,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    bool requireAuth = true,
    String? idempotencyKey,
  }) async {
    final headers = <String, dynamic>{
      'X-localization': AppConstants.defaultLanguage,
    };
    if (requireAuth) {
      final auth = dio.options.headers[HttpHeaders.authorizationHeader];
      if (auth != null && auth.toString().isNotEmpty) {
        headers[HttpHeaders.authorizationHeader] = auth;
      }
    }
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    try {
      return await dio.post(
        uri,
        data: data,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: Options(headers: headers),
      );
    } on DioException {
      rethrow;
    }
  }

  Future<Response> put(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    bool requireAuth = true,
    String? idempotencyKey,
  }) async {
    try {
      final options = Options();
      if (!requireAuth) {
        // Public endpoint — strip the Authorization header.
        options.headers = {
          HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
          'X-localization': AppConstants.defaultLanguage,
        };
      }
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
        final headers = options.headers ?? <String, dynamic>{};
        headers['Idempotency-Key'] = idempotencyKey;
        options.headers = headers;
      }
      return await dio.put(
        uri,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        options: options,
      );
    } on DioException catch (e) {
      _handleUnauthorizedResponse(e, requireAuth: requireAuth);
      rethrow;
    } on FormatException {
      throw const FormatException("Unable to process the data");
    } catch (e) {
      rethrow;
    }
  }

  Future<Response> patch(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    bool requireAuth = true,
    String? idempotencyKey,
  }) async {
    try {
      final options = Options();
      if (!requireAuth) {
        // Public endpoint — strip the Authorization header.
        options.headers = {
          HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
          'X-localization': AppConstants.defaultLanguage,
        };
      }
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
        final headers = options.headers ?? <String, dynamic>{};
        headers['Idempotency-Key'] = idempotencyKey;
        options.headers = headers;
      }
      return await dio.patch(
        uri,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
        options: options,
      );
    } on DioException catch (e) {
      _handleUnauthorizedResponse(e, requireAuth: requireAuth);
      AppLogger.warn(
        'DioClient',
        'PATCH $uri failed (${e.type.name}, status=${e.response?.statusCode})',
      );
      rethrow;
    } on FormatException {
      throw const FormatException("Unable to process the data");
    } catch (e) {
      rethrow;
    }
  }

  /// Authenticated POST used only by sign-out to revoke the session upstream.
  ///
  /// Deliberately not `post(...)`, because both of that method's behaviours are
  /// wrong here:
  /// - a 401 must NOT call [markSessionInvalidated] — the token being rejected
  ///   is the goal of the request, not evidence of a takeover, and raising the
  ///   "Session Ended" modal mid-logout would be nonsense;
  /// - the request must not wait on connectivity, so an offline sign-out
  ///   completes locally at once instead of blocking on
  ///   [NetworkInterceptor]'s five-minute wait.
  ///
  /// Short timeouts for the same reason: sign-out is a foreground action and
  /// the local wipe is what actually matters.
  Future<Response> logoutRevoke(String uri) async {
    return dio.post(
      uri,
      data: const <String, dynamic>{},
      options: Options(
        extra: {NetworkInterceptor.skipConnectivityWaitKey: true},
        sendTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
      ),
    );
  }

  Future<Response> delete(
    String uri, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      return await dio.delete(
        uri,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      _handleUnauthorizedResponse(e, requireAuth: true);
      rethrow;
    } on FormatException {
      throw const FormatException("Unable to process the data");
    } catch (e) {
      rethrow;
    }
  }
}
