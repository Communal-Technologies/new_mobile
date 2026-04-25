import 'dart:developer' as developer;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:communal_mobile/data/datasources/remote/dio/logging_interceptor.dart';
import 'package:communal_mobile/data/datasources/remote/dio/network_interceptor.dart';
import 'package:communal_mobile/core/constants/constants.dart';
import 'package:communal_mobile/core/security/session_invalidation_notifier.dart';

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

  void _devLog(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (!kDebugMode) return;
    developer.log(
      message,
      name: 'DioClient',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void print(Object? object) {
    if (!kDebugMode) return;
    developer.log((object ?? '').toString(), name: 'DioClient');
  }

  void debugPrint(String? message, {int? wrapWidth}) {
    if (!kDebugMode) return;
    if (message == null) return;
    developer.log(message, name: 'DioClient');
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

    final isDebug = dotenv.env['APP_ENV'] == 'development';

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
    _logRequest('GET', uri, queryParameters);
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
  }) async {
    _logRequest('POST', uri, queryParameters, data);
      _devLog('📤 DioClient POST: $uri');
      _devLog('📤 RequireAuth: $requireAuth');
      print('📤 DioClient POST: $uri');
      print('📤 RequireAuth: $requireAuth');
      try {
        final options = Options();
        if (!requireAuth) {
          // Remove authorization header for public endpoints
          options.headers = {
            HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
            'X-localization': AppConstants.defaultLanguage,
          };
          _devLog('📤 Headers (no auth): ${options.headers}');
          print('📤 Headers (no auth): ${options.headers}');
        } else {
          _devLog('📤 Headers (with auth): ${dio.options.headers}');
          print('📤 Headers (with auth): ${dio.options.headers}');
        }
        
        _devLog('📤 Making POST request to: $baseUrl$uri');
        print('📤 Making POST request to: $baseUrl$uri');
        final response = await dio.post(
        uri,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
          options: options,
        );
        _devLog('📥 DioClient POST Response: Status ${response.statusCode}');
        _devLog('📥 Response Data: ${response.data}');
        print('📥 DioClient POST Response: Status ${response.statusCode}');
        print('📥 Response Data: ${response.data}');
        return response;
      } on DioException catch (e) {
        _handleUnauthorizedResponse(e, requireAuth: requireAuth);
        _devLog('❌ DioClient POST DioException', error: e);
        _devLog('❌ Error Type: ${e.type}');
        _devLog('❌ Error Message: ${e.message}');
        _devLog('❌ Response Status: ${e.response?.statusCode}');
        _devLog('❌ Response Data: ${e.response?.data}');
        print('❌ DioClient POST DioException');
        print('❌ Error Type: ${e.type}');
        print('❌ Error Message: ${e.message}');
        print('❌ Response Status: ${e.response?.statusCode}');
        print('❌ Response Data: ${e.response?.data}');
        rethrow;
      } on FormatException catch (e) {
        _devLog('❌ DioClient POST FormatException: $e');
        print('❌ DioClient POST FormatException: $e');
      throw const FormatException("Unable to process the data");
      } catch (e, stackTrace) {
        _devLog('❌ DioClient POST Unexpected Error: $e', error: e, stackTrace: stackTrace);
        print('❌ DioClient POST Unexpected Error: $e');
        print('❌ Stack Trace: $stackTrace');
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
  }) async {
    _logRequest('POST', uri, null, '(FormData)');
    final headers = <String, dynamic>{
      'X-localization': AppConstants.defaultLanguage,
    };
    if (requireAuth) {
      final auth = dio.options.headers[HttpHeaders.authorizationHeader];
      if (auth != null && auth.toString().isNotEmpty) {
        headers[HttpHeaders.authorizationHeader] = auth;
      }
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
  }) async {
    _logRequest('PUT', uri, queryParameters, data);
    try {
      final options = Options();
      if (!requireAuth) {
        // Remove authorization header for public endpoints
        options.headers = {
          HttpHeaders.contentTypeHeader: 'application/json; charset=UTF-8',
          'X-localization': AppConstants.defaultLanguage,
        };
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
    _logRequest('DELETE', uri, queryParameters, data);
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

  void _logRequest(
    String method,
    String uri,
    Map<String, dynamic>? params, [
    dynamic data,
  ]) {
    if (dotenv.env['APP_ENV'] == 'development') {
      debugPrint('[$method] $baseUrl$uri');
      if (params != null) debugPrint('Query: $params');
      if (data != null) debugPrint('Body: $data');
    }
  }
}
