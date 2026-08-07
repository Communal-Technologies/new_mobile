import 'package:flutter/foundation.dart';

/// Broadcasts "the member's money just moved" to anywhere on the home screen
/// that renders it.
///
/// The recent-transactions list used to reload only when the wallet balance
/// changed, which made it dependent on the balance arriving first. A deposit
/// whose balance landed late showed up late, and a movement that left the
/// balance unchanged never showed up at all until the screen was rebuilt for
/// some other reason.
///
/// Backed by a [ValueNotifier] counter rather than a stream so listeners can
/// attach with [ValueListenableBuilder] and cannot miss a tick by subscribing
/// late — the same shape as [UnreadNotificationsService].
///
/// Ping points:
///   - a transaction-typed push arriving in the foreground,
///   - a transaction-typed push being tapped from the tray,
///   - a transfer completing in-app, where the sender already knows.
class TransactionActivityService {
  /// Increments on every known movement. The value itself is meaningless; only
  /// the change matters.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  void ping() {
    revision.value = revision.value + 1;
  }

  /// True when a push describes a wallet movement, so the caller does not have
  /// to duplicate the type matching the deep-link router does. Kept in sync
  /// with the `type` values txnsvc sends in its alert payloads.
  static bool describesMovement(Map<String, dynamic> data) {
    final type = (data['type']?.toString() ?? '').trim();
    if (type == 'transaction' || type == 'transaction-receipt') {
      return true;
    }
    return (data['route']?.toString() ?? '').trim() == 'transaction-receipt';
  }
}
