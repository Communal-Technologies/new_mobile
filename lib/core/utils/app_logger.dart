import 'package:flutter/foundation.dart';

/// Centralized logger that no-ops in release builds.
///
/// Why this exists (audit M15-M18): release artifacts were leaking
/// `Authorization: Bearer …` headers, full response bodies, password lengths,
/// and user-info JSON via `print()` calls. Routing every diagnostic through
/// `AppLogger` and bailing out under [kReleaseMode] makes it impossible to
/// add new leaks accidentally.
class AppLogger {
  AppLogger._();

  /// Header names that must be masked before logging. Compared
  /// case-insensitively. Keep in sync with anything sensitive the SPA / mobile
  /// auth bridge introduces.
  static const Set<String> _sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'proxy-authorization',
    'x-xsrf-token',
    'xsrf-token',
  };

  static void debug(String tag, String message,
      {Object? error, StackTrace? stackTrace}) {
    if (kReleaseMode) return;
    debugPrint('[$tag] $message'
        '${error != null ? '\n  error: $error' : ''}'
        '${stackTrace != null ? '\n$stackTrace' : ''}');
  }

  static void info(String tag, String message) {
    if (kReleaseMode) return;
    debugPrint('[$tag] $message');
  }

  static void warn(String tag, String message, {Object? error}) {
    if (kReleaseMode) return;
    debugPrint('[$tag] [WARN] $message'
        '${error != null ? '\n  error: $error' : ''}');
  }

  static void error(String tag, String message,
      {Object? error, StackTrace? stackTrace}) {
    if (kReleaseMode) return;
    debugPrint('[$tag] [ERROR] $message'
        '${error != null ? '\n  error: $error' : ''}'
        '${stackTrace != null ? '\n$stackTrace' : ''}');
  }

  /// Returns a copy of [headers] with sensitive values replaced by `***`.
  /// Use before passing headers to any logger.
  static Map<String, dynamic> redactHeaders(Map<String, dynamic>? headers) {
    if (headers == null || headers.isEmpty) return const {};
    return <String, dynamic>{
      for (final entry in headers.entries)
        entry.key: _sensitiveHeaders.contains(entry.key.toLowerCase())
            ? '***'
            : entry.value,
    };
  }
}

/// Legacy free-function used by existing call sites. Routes through
/// [AppLogger.debug] so it inherits the release no-op guard. Prefer
/// `AppLogger.*` directly in new code.
@Deprecated('Use AppLogger.debug / AppLogger.info instead.')
void appLog(dynamic data, [dynamic data2]) {
  AppLogger.debug('AppLog', data2 == null ? '$data' : '$data | $data2');
}
