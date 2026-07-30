import 'package:dio/dio.dart';

import 'package:communal_mobile/core/utils/app_logger.dart';

/// Network logging interceptor.
///
/// Audit M16: previously logged `options.headers` (including
/// `Authorization: Bearer …`) and full response bodies. Now logs method +
/// path + status only, and redacts headers before they ever hit the logger.
/// Bodies are never logged here — if you need to inspect a body during
/// development, do it at the call site behind a `kDebugMode` guard with the
/// fields you actually need.
class LoggingInterceptor extends Interceptor {
  LoggingInterceptor();

  static const String _tag = 'Net';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    AppLogger.debug(_tag, '--> ${options.method} ${options.uri.path}');
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    AppLogger.debug(
      _tag,
      '<-- ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.uri.path}',
    );
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    AppLogger.warn(
      _tag,
      'xx ${err.response?.statusCode ?? '???'} '
      '${err.requestOptions.method} ${err.requestOptions.uri.path} '
      '(${err.type.name})',
    );
    super.onError(err, handler);
  }
}
