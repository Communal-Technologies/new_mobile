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
    final base = _baseDioMessage(error);
    // 429: surface the server's Retry-After hint so the user sees
    // "try again in 23s" instead of the generic "too many requests"
    // message that gives no signal about when to retry.
    if (error.response?.statusCode == 429) {
      final retry = _retryAfterSeconds(error.response?.headers.map);
      if (retry != null && retry > 0) {
        return '$base Try again in ${_humanizeDuration(retry)}.';
      }
    }
    return base;
  }
  if (error is Exception) {
    final s = error.toString();
    if (s.startsWith('Exception: ')) return s.substring('Exception: '.length);
    return s;
  }
  return DioTransportUserMessages.generic;
}

String _baseDioMessage(DioException error) {
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

/// Read the server's `Retry-After` header. Per RFC, it's either an
/// integer count of seconds OR an HTTP-date. Laravel's RateLimiter
/// always emits the integer form, but we tolerate either so swapping
/// in a CDN/WAF later doesn't break the parse.
int? _retryAfterSeconds(Map<String, List<String>>? headers) {
  if (headers == null) return null;
  // Header lookup is case-insensitive.
  List<String>? raw;
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == 'retry-after') {
      raw = entry.value;
      break;
    }
  }
  if (raw == null || raw.isEmpty) return null;
  final value = raw.first.trim();
  final asInt = int.tryParse(value);
  if (asInt != null) return asInt;
  final asDate = DateTime.tryParse(value);
  if (asDate != null) {
    final delta = asDate.difference(DateTime.now()).inSeconds;
    return delta > 0 ? delta : null;
  }
  return null;
}

String _humanizeDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  final minutes = (seconds / 60).round();
  if (minutes < 60) return '$minutes min';
  final hours = (minutes / 60).round();
  return '${hours}h';
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
