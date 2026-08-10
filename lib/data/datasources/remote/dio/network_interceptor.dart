import 'package:dio/dio.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';

class NetworkInterceptor extends Interceptor {
  final ConnectivityCubit connectivityCubit;

  NetworkInterceptor(this.connectivityCubit);

  /// `extra` flag for requests that must fail fast instead of waiting for the
  /// network. Sign-out sets it: a user asking to log out while offline has to
  /// be logged out now, not in five minutes when connectivity returns.
  static const String skipConnectivityWaitKey = 'skipConnectivityWait';

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[skipConnectivityWaitKey] == true &&
        !connectivityCubit.isConnected) {
      return handler.reject(
        DioException(
          requestOptions: options,
          error: 'No internet connection.',
          type: DioExceptionType.connectionError,
        ),
      );
    }

    // Check if we have connectivity before making the request
    if (!connectivityCubit.isConnected) {
      // Wait for connection to be restored
      try {
        final connected = await connectivityCubit.waitForConnection(
          timeout: const Duration(minutes: 5), // Max wait time
        );

        if (!connected) {
          return handler.reject(
            DioException(
              requestOptions: options,
              error: 'No internet connection. Please check your network and try again.',
              type: DioExceptionType.connectionTimeout,
            ),
          );
        }
      } catch (e, stackTrace) {
        // Audit M34: preserve the original cause inside the wrapping
        // DioException so error handlers / Crashlytics see the actual
        // failure type (e.g. SocketException vs PlatformException) and
        // can branch accordingly. Previously the wrapped exception
        // collapsed every connectivity-wait failure into the same
        // string-typed error.
        return handler.reject(
          DioException(
            requestOptions: options,
            error: e,
            stackTrace: stackTrace,
            message:
                'Failed to connect. Please check your internet connection.',
            type: DioExceptionType.connectionTimeout,
          ),
        );
      }
    }

    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // When an upstream is down, Nginx / PHP-FPM / a WAF returns an HTML
    // error page (text/html) instead of our JSON envelope. Dio hands that
    // body to callers as a raw String, and repositories that do
    // `errorMessage = responseData` (or `e.toString()`) then paint the raw
    // HTML on screen. Detect a non-JSON body here — the single chokepoint
    // every request's error passes through — and rewrite it into the
    // `{message: …}` shape the repositories already expect, so the friendly
    // copy surfaces instead of markup.
    final data = err.response?.data;
    final contentType =
        err.response?.headers.value('content-type')?.toLowerCase() ?? '';
    final looksHtml = data is String &&
        (data.trimLeft().startsWith('<') || contentType.contains('text/html'));
    if (looksHtml) {
      err.response!.data = {
        'message': 'The server is currently unavailable. Please try again.',
      };
    }

    // Handle network errors
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) {
      // Check if it's a connectivity issue
      if (!connectivityCubit.isConnected) {
        // This will be handled by waiting in onRequest
        handler.reject(err);
        return;
      }
    }

    super.onError(err, handler);
  }
}

