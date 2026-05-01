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

/// User-facing one-line message for any error caught at a UI boundary.
/// Centralised so toasts / snackbars / inline banners stop dumping
/// `DioException [bad_response]: …` plus a stack into the UI when a
/// network call fails.
///
/// Resolution order:
///   1. Laravel-shaped 422 with a non-empty `errors` map — surface the
///      first field error (e.g. "Provider must be one of: …") rather
///      than the generic envelope `message`. Without this, every
///      validation rejection landed in the UI as the unhelpful "The
///      given data was invalid." string.
///   2. DioException with a Laravel-shaped error body
///      (`response.data['message']` is a non-empty string) — surface
///      the server's own copy verbatim.
///   3. DioException without a message → [dioTransportUserMessage]
///      maps the transport class to a friendly string.
///   4. `Exception('foo')` → strip the redundant `Exception: ` prefix.
///   5. Anything else → fall back to the generic transport message.
String humanizeError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final fieldError = _firstFieldError(data['errors']);
      if (fieldError != null) return fieldError;
      final raw = data['message'];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.trim();
      }
    }
    return dioTransportUserMessage(error);
  }
  if (error is Exception) {
    final s = error.toString();
    if (s.startsWith('Exception: ')) return s.substring('Exception: '.length);
    return s;
  }
  return DioTransportUserMessages.generic;
}

/// Pull the first usable field message from a Laravel 422 `errors`
/// payload. Laravel emits `{ field: [msg, …] }` — there's no
/// guaranteed iteration order so picking "first" is heuristic, but
/// surfacing any field message beats the generic envelope copy.
String? _firstFieldError(dynamic errors) {
  if (errors is! Map) return null;
  for (final entry in errors.values) {
    if (entry is List) {
      for (final item in entry) {
        if (item is String && item.trim().isNotEmpty) return item.trim();
      }
    } else if (entry is String && entry.trim().isNotEmpty) {
      return entry.trim();
    }
  }
  return null;
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
