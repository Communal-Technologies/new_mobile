import 'package:flutter/foundation.dart';

import 'package:communal_mobile/data/repositories/notifications_repository.dart';

/// Lightweight singleton that broadcasts the member's current unread
/// notification count to anywhere in the app that wants to render a
/// badge (today: the home-header bell). Backed by [ValueNotifier] so
/// consumers can use [ValueListenableBuilder] without dragging in a
/// full bloc just for an integer.
///
/// Refresh points:
///   - app cold-start, once the auth state is known,
///   - after the Notifications screen mark-read / mark-all-read calls,
///   - whenever a push lands with a notification_id (handler calls
///     [refresh] so the bell updates without waiting for a poll).
class UnreadNotificationsService {
  UnreadNotificationsService(this._repo);

  final NotificationsRepository _repo;
  final ValueNotifier<int> count = ValueNotifier<int>(0);

  bool _inFlight = false;

  /// Re-fetch the unread count from the backend. Silently swallows
  /// errors — the bell falling back to "no badge" is preferable to
  /// surfacing a network blip on the home screen.
  Future<void> refresh() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final next = await _repo.unreadCount();
      if (next != count.value) {
        count.value = next;
      }
    } catch (_) {
      // Leave the previous value in place. Next refresh will reconcile.
    } finally {
      _inFlight = false;
    }
  }

  /// Apply a local delta when we know the count just changed without
  /// waiting on the network (e.g. user just tapped "Mark all read"
  /// in the Notifications screen). Caller still calls [refresh] for
  /// the authoritative number.
  void decrement([int by = 1]) {
    final next = count.value - by;
    count.value = next < 0 ? 0 : next;
  }

  void clear() {
    count.value = 0;
  }
}
