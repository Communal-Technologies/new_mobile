/// Holds a single pending route intent to be navigated to AFTER the
/// app finishes any in-progress lock / authentication step.
///
/// The push-notification handler can fire while the SecurityCubit has
/// the app locked behind WelcomeBackScreen — `goNamed` would silently
/// drop because the locked overlay replaces the entire MaterialApp.
/// The handler stashes the intent here; the security wrapper consumes
/// it once unlock completes and the original MaterialApp is restored.
class DeepLinkIntent {
  const DeepLinkIntent({required this.routeName, this.extra});

  final String routeName;
  final Object? extra;
}

class PendingDeepLinkService {
  DeepLinkIntent? _pending;

  bool get hasPending => _pending != null;

  void store(DeepLinkIntent intent) {
    _pending = intent;
  }

  /// Atomically read + clear. Callers wire this into a unlock
  /// listener so the intent can never replay twice.
  DeepLinkIntent? consume() {
    final out = _pending;
    _pending = null;
    return out;
  }
}
