import 'package:flutter/foundation.dart';

/// Global signal set when backend returns 401 for an authenticated request.
///
/// Used to block app interaction on a stale/revoked session (e.g. session takeover
/// from another device) until the user logs out.
final ValueNotifier<String?> sessionInvalidationMessage = ValueNotifier<String?>(
  null,
);

void markSessionInvalidated([String? message]) {
  final resolved = (message ?? '').trim();
  sessionInvalidationMessage.value = resolved.isEmpty
      ? 'Your session is no longer valid on this device. Please log out to continue.'
      : resolved;
}

void clearSessionInvalidation() {
  sessionInvalidationMessage.value = null;
}
