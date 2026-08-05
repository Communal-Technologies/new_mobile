import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Module-level timestamp shared across every root tab so the
/// "press back again to exit" gesture survives switching tabs in
/// between presses (matches stock Android behaviour: hit back on
/// Home, swipe to Settings, hit back again → exits without re-arming).
DateTime? _lastRootBackPress;

const Duration _exitWindow = Duration(seconds: 2);

/// Wrap the body of a root-tab screen (Home, Loans, Obligations,
/// Community, Account Settings, Transfer, Transaction history) with
/// this widget so the Android hardware back button shows a "Press
/// back again to exit" snackbar instead of immediately closing the
/// app.
///
/// First press inside the [_exitWindow]:
///   - Captures the timestamp.
///   - Surfaces a floating snackbar near the footer.
///
/// Second press inside the same window:
///   - Calls [SystemNavigator.pop] so Android moves the task to the
///     background (Android's idiomatic "exit" — full kill is reserved
///     for the OS).
///
/// Detail screens push deeper than a root tab and SHOULD pop on back —
/// that's the default behaviour and we leave them untouched. Only
/// wrap the screens that sit at the bottom of the navigation stack
/// (i.e. the BottomNavBar destinations).
class BackToExitWrapper extends StatelessWidget {
  const BackToExitWrapper({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      // onPopInvokedWithResult lands on Flutter 3.22+; older versions
      // can swap to `onPopInvoked` with the same body.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final now = DateTime.now();
        final last = _lastRootBackPress;
        if (last != null && now.difference(last) < _exitWindow) {
          // Second press inside the window — exit.
          SystemNavigator.pop();
          return;
        }
        _lastRootBackPress = now;
        // Floating snackbar near the bottom edge so it sits above the
        // BottomNavBar and reads as the system asking for confirmation.
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Press back again to exit'),
            duration: _exitWindow,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
