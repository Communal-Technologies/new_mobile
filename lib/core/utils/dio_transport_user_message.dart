import 'dart:io';

import 'package:dio/dio.dart';

/// User-facing strings for transport-layer failures (aligned with splash cold start).
abstract final class DioTransportUserMessages {
  DioTransportUserMessages._();

  static const String timeout =
      'Request timed out. Check your connection and try again.';
  static const String noConnection =
      'No internet connection. Check your network and try again.';
  static const String couldNotReachServer =
      'Could not reach the server. Please try again.';
  static const String generic = 'Something went wrong. Please try again.';

  static String serverError(int code) =>
      'Server error ($code). Please try again later.';
}

/// Same mapping as [SplashCubit] used for settings/regions — keep messages in one place.
String dioTransportUserMessage(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return DioTransportUserMessages.timeout;
    case DioExceptionType.connectionError:
      return DioTransportUserMessages.noConnection;
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode;
      if (code != null) {
        return DioTransportUserMessages.serverError(code);
      }
      return DioTransportUserMessages.couldNotReachServer;
    case DioExceptionType.unknown:
      if (e.error is SocketException) {
        return DioTransportUserMessages.noConnection;
      }
      break;
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
      break;
  }
  return DioTransportUserMessages.generic;
}

/// True when the failure is likely unreachable server / network (not e.g. 401 validation).
bool isDioTransportFailure(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
      return true;
    case DioExceptionType.badResponse:
      final code = e.response?.statusCode;
      return code == null || code >= 500;
    case DioExceptionType.unknown:
      return e.error is SocketException;
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
      return false;
  }
}

/// Auth screens send the user back to splash for the same class of errors splash shows inline.
bool shouldRedirectToSplashForAuthFailure(String message) {
  if (message == DioTransportUserMessages.timeout ||
      message == DioTransportUserMessages.noConnection ||
      message == DioTransportUserMessages.couldNotReachServer) {
    return true;
  }
  if (message.startsWith('Server error (')) return true;
  return false;
}
