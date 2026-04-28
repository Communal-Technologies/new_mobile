import 'package:flutter/foundation.dart';

/// Bridges [AuthBloc] state into a [Listenable] that go_router's
/// `refreshListenable` understands.
///
/// The router's redirect callback runs synchronously and can't `await` the
/// bloc, so we mirror the four pieces of state it needs ([isAuthenticated],
/// [isResolved], [hasCompletedKyc], [hasCooperative]) into this notifier and
/// call [notifyListeners] on every transition. That triggers a re-evaluation
/// of `redirect` so a fresh logout (or a freshly-detected expired session)
/// bounces the user out of any protected route immediately, and a KYC
/// completion / cooperative join flips the visible nav as soon as the new
/// `AuthAuthenticated` state lands.
///
/// Audit M29.
class AuthStatusNotifier extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isResolved = false;
  bool _hasCompletedKyc = false;
  bool _hasCooperative = false;

  /// `true` once the user holds a verified session.
  bool get isAuthenticated => _isAuthenticated;

  /// `false` while the splash / `AppStarted` flow is still running. The
  /// redirect callback uses this to avoid bouncing the user during the
  /// brief window between launch and the first auth-state emission.
  bool get isResolved => _isResolved;

  /// Mirrors [UserModel.hasCompletedKyc] from the latest [AuthAuthenticated]
  /// state. The router blocks every protected route except `/kyc/*` while
  /// this is `false`.
  bool get hasCompletedKyc => _hasCompletedKyc;

  /// Mirrors [UserModel.hasCooperativeMembership]. The router uses this to
  /// strip cooperative-only routes (loans, obligations) from non-coop users.
  bool get hasCooperative => _hasCooperative;

  void update({
    required bool isAuthenticated,
    required bool isResolved,
    bool hasCompletedKyc = false,
    bool hasCooperative = false,
  }) {
    if (_isAuthenticated == isAuthenticated &&
        _isResolved == isResolved &&
        _hasCompletedKyc == hasCompletedKyc &&
        _hasCooperative == hasCooperative) {
      return;
    }
    _isAuthenticated = isAuthenticated;
    _isResolved = isResolved;
    _hasCompletedKyc = hasCompletedKyc;
    _hasCooperative = hasCooperative;
    notifyListeners();
  }
}

/// Single global notifier the [appRouter] subscribes to. Updated by a
/// [BlocListener] in `MyApp` whenever [AuthBloc] emits.
final AuthStatusNotifier appAuthStatusNotifier = AuthStatusNotifier();
