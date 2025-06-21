import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:communal_mobile/data/datasources/remote/dio/logging_interceptor.dart';
import 'package:communal_mobile/core/constants/constants.dart';

class DioClient {
  final String baseUrl;
  final LoggingInterceptor loggingInterceptor;

  Dio dio = Dio();
  String? _token;

  DioClient(
    this.baseUrl, {
    required this.loggingInterceptor,
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
  }) async {
    _logRequest('GET', uri, queryParameters);
    try {
      return await dio.get(
        uri,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
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
  }) async {
    _logRequest('POST', uri, queryParameters, data);
    try {
      return await dio.post(
        uri,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on FormatException {
      throw const FormatException("Unable to process the data");
    } catch (e) {
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
  }) async {
    _logRequest('PUT', uri, queryParameters, data);
    try {
      return await dio.put(
        uri,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
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
