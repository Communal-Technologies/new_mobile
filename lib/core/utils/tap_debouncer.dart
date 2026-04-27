import 'package:flutter/foundation.dart';

/// Audit M28: cheap insurance against rapid double-taps on action
/// buttons (Send Money, Confirm Transfer, Pay) that could otherwise
/// double-fire the underlying handler.
///
/// Today the screens rely on `_isAuthenticating` / `_submitting` flags
/// to disable buttons during in-flight requests, but those flags are set
/// inside the async handler — between the user's two taps and the
/// `setState` call there's a frame-or-two race where two handlers can
/// queue. The audit calls this out as "no client-side rate limit on
/// rapid taps; relying on UX (disabled buttons) only".
///
/// Usage
/// -----
/// ```dart
/// final _tapDebouncer = TapDebouncer();
/// // ...
/// onPressed: () => _tapDebouncer.run(_doExpensiveThing),
/// ```
///
/// `run` returns immediately if a tap landed within the last
/// [cooldown] (default 800ms) OR a previous run is still in-flight;
/// otherwise it invokes `action` and records the new tap timestamp.
/// Async actions are awaited so two taps during a long-running request
/// don't both fire even if they're further apart than the cooldown.
///
/// State is per-instance — instantiate one per button (typically as a
/// `final` field on the screen's State).
class TapDebouncer {
  TapDebouncer({this.cooldown = const Duration(milliseconds: 800)});

  final Duration cooldown;
  DateTime? _lastFired;
  bool _inFlight = false;

  Future<void> run(Future<void> Function() action) async {
    final now = DateTime.now();
    if (_inFlight) return;
    final last = _lastFired;
    if (last != null && now.difference(last) < cooldown) return;
    _lastFired = now;
    _inFlight = true;
    try {
      await action();
    } finally {
      _inFlight = false;
      _lastFired = DateTime.now();
    }
  }

  /// Sync convenience for void callbacks (most button handlers).
  void runSync(VoidCallback action) {
    run(() async {
      action();
    });
  }
}
