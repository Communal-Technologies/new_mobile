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
        HttpHeaders.authorizationHeader: _token != null ? 'Bearer $_token' : '',
        'X-localization': AppConstants.defaultLanguage, // Replace with runtime language if needed
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
    // Note: [ServerStatusInterceptor] is appended at runtime by
    // `injection.dart` after this client is constructed — see the
    // server_status_cubit comment there for why we don't @injectable
    // it through here.

    // Only add logger in dev
    if (isDebug) {
      dio.interceptors.add(loggingInterceptor);
    }
  }

  void updateToken(String token) {
    _token = token;
    dio.options.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
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
  }) async {
    try {
      return await dio.get(
        uri,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
        options: requireAuth
            ? null
            : Options(
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
