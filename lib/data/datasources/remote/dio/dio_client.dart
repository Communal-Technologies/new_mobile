import 'dart:io';
import 'package:dio/dio.dart';
import 'package:communal_mobile/data/datasources/remote/dio/logging_interceptor.dart';
import 'package:communal_mobile/data/datasources/remote/dio/network_interceptor.dart';
import 'package:communal_mobile/core/constants/constants.dart';
import 'package:communal_mobile/core/security/session_invalidation_notifier.dart';
import 'package:communal_mobile/core/utils/app_logger.dart';

class DioClient {
  final String baseUrl;
  final LoggingInterceptor loggingInterceptor;
  final NetworkInterceptor? networkInterceptor;

  Dio dio = Dio();
  String? _token;

  DioClient(
    this.baseUrl, {
    required this.loggingInterceptor,
    this.networkInterceptor,
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
      ..options.receiveTimeout = const Duration(seconds: 30)
      ..options.headers = {
        HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
        HttpHeaders.authorizationHeader: _token != null ? 'Bearer $_token' : '',
        'X-localization': AppConstants.defaultLanguage, // Replace with runtime language if needed
      };

    final isDebug = AppConstants.appEnvironment == 'development';

    // Add network interceptor first (so it can wait for connectivity)
    if (networkInterceptor != null) {
      dio.interceptors.insert(0, networkInterceptor!);
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
