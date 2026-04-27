import 'package:flutter/foundation.dart';

/// Bridges [AuthBloc] state into a [Listenable] that go_router's
/// `refreshListenable` understands.
///
/// The router's redirect callback runs synchronously and can't `await` the
/// bloc, so we mirror the two pieces of state it needs ([isAuthenticated],
/// [isResolved]) into this notifier and call [notifyListeners] on every
/// transition. That triggers a re-evaluation of `redirect` so a fresh logout
/// (or a freshly-detected expired session) bounces the user out of any
/// protected route immediately.
///
/// Audit M29.
class AuthStatusNotifier extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isResolved = false;

  /// `true` once the user holds a verified session.
  bool get isAuthenticated => _isAuthenticated;

  /// `false` while the splash / `AppStarted` flow is still running. The
  /// redirect callback uses this to avoid bouncing the user during the
  /// brief window between launch and the first auth-state emission.
  bool get isResolved => _isResolved;

  void update({required bool isAuthenticated, required bool isResolved}) {
    if (_isAuthenticated == isAuthenticated && _isResolved == isResolved) {
      return;
    }
    _isAuthenticated = isAuthenticated;
    _isResolved = isResolved;
    notifyListeners();
  }
}

/// Single global notifier the [appRouter] subscribes to. Updated by a
/// [BlocListener] in `MyApp` whenever [AuthBloc] emits.
final AuthStatusNotifier appAuthStatusNotifier = AuthStatusNotifier();
