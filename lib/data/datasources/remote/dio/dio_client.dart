import 'dart:developer' as developer;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:communal_mobile/core/utils/app_logger.dart';
import 'package:communal_mobile/data/datasources/remote/dio/logging_interceptor.dart';
import 'package:communal_mobile/data/datasources/remote/dio/network_interceptor.dart';
import 'package:communal_mobile/core/constants/constants.dart';

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
      developer.log('📤 DioClient POST: $uri', name: 'DioClient');
      developer.log('📤 RequireAuth: $requireAuth', name: 'DioClient');
      appLog('DioClient POST', 'URI: $uri, RequireAuth: $requireAuth');
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
          developer.log('📤 Headers (no auth): ${options.headers}', name: 'DioClient');
          appLog('DioClient Headers', 'No auth: ${options.headers}');
          print('📤 Headers (no auth): ${options.headers}');
        } else {
          developer.log('📤 Headers (with auth): ${dio.options.headers}', name: 'DioClient');
          print('📤 Headers (with auth): ${dio.options.headers}');
        }
        
        developer.log('📤 Making POST request to: $baseUrl$uri', name: 'DioClient');
        appLog('DioClient POST Request', 'URL: $baseUrl$uri, Data: $data');
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
        developer.log('📥 DioClient POST Response: Status ${response.statusCode}', name: 'DioClient');
        developer.log('📥 Response Data: ${response.data}', name: 'DioClient');
        appLog('DioClient POST Response', 'Status: ${response.statusCode}, Data: ${response.data}');
        print('📥 DioClient POST Response: Status ${response.statusCode}');
        print('📥 Response Data: ${response.data}');
        return response;
      } on DioException catch (e) {
        developer.log('❌ DioClient POST DioException', name: 'DioClient', error: e);
        developer.log('❌ Error Type: ${e.type}', name: 'DioClient');
        developer.log('❌ Error Message: ${e.message}', name: 'DioClient');
        developer.log('❌ Response Status: ${e.response?.statusCode}', name: 'DioClient');
        developer.log('❌ Response Data: ${e.response?.data}', name: 'DioClient');
        appLog('DioClient POST ERROR', 'Type: ${e.type}, Message: ${e.message}, Status: ${e.response?.statusCode}, Data: ${e.response?.data}');
        print('❌ DioClient POST DioException');
        print('❌ Error Type: ${e.type}');
        print('❌ Error Message: ${e.message}');
        print('❌ Response Status: ${e.response?.statusCode}');
        print('❌ Response Data: ${e.response?.data}');
        rethrow;
      } on FormatException catch (e) {
        developer.log('❌ DioClient POST FormatException: $e', name: 'DioClient');
        appLog('DioClient FormatException', e.toString());
        print('❌ DioClient POST FormatException: $e');
      throw const FormatException("Unable to process the data");
      } catch (e, stackTrace) {
        developer.log('❌ DioClient POST Unexpected Error: $e', name: 'DioClient', error: e, stackTrace: stackTrace);
        appLog('DioClient Unexpected Error', 'Error: $e');
        print('❌ DioClient POST Unexpected Error: $e');
        print('❌ Stack Trace: $stackTrace');
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
