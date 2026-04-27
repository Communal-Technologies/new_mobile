import 'package:dio/dio.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';

class NetworkInterceptor extends Interceptor {
  final ConnectivityCubit connectivityCubit;

  NetworkInterceptor(this.connectivityCubit);

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
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

