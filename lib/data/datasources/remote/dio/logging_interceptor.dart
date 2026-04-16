import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class LoggingInterceptor extends Interceptor {
  final int maxCharactersPerLine;

  LoggingInterceptor({this.maxCharactersPerLine = 200});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('--> ${options.method} ${options.uri}');
      debugPrint('Headers: ${options.headers}');
      if (options.data != null) debugPrint('Body: ${options.data}');
    }

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('<-- ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri}');

      final responseStr = response.data.toString();
      if (responseStr.length > maxCharactersPerLine) {
        final iterations = (responseStr.length / maxCharactersPerLine).ceil();
        for (int i = 0; i < iterations; i++) {
          final start = i * maxCharactersPerLine;
          final end = (i + 1) * maxCharactersPerLine;
          debugPrint(responseStr.substring(start, end > responseStr.length ? responseStr.length : end));
        }
      } else {
        debugPrint(responseStr);
      }

      debugPrint('<-- END HTTP');
    }

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      debugPrint('*** DioError ***');
      debugPrint('URI: ${err.requestOptions.uri}');
      debugPrint('Message: ${err.message}');
      if (err.response != null) {
        debugPrint('Status Code: ${err.response?.statusCode}');
        debugPrint('Response: ${err.response?.data}');
      }
      debugPrint('*** End DioError ***');
    }

    super.onError(err, handler);
  }
}
