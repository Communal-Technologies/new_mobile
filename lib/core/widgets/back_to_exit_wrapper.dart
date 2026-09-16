import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Module-level timestamp shared across every root tab so the
/// "press back again to exit" gesture survives switching tabs in
/// between presses (matches stock Android behaviour: hit back on
/// Home, swipe to Settings, hit back again → exits without re-arming).
DateTime? _lastRootBackPress;

const Duration _exitWindow = Duration(seconds: 2);

/// Back handling for the screens the bottom navigation can land on.
///
/// Back returns to the screen the member came from whenever there is one.
/// Only when the screen is the bottom of the stack does it fall back to
/// [fallbackRoute] (for screens that are not a tab, such as Transfer) or, on a
/// real tab, ask for a second press within [_exitWindow] before
/// [SystemNavigator.pop] moves the app to the background.
class BackToExitWrapper extends StatelessWidget {
  const BackToExitWrapper({super.key, required this.child, this.fallbackRoute});

  final Widget child;
  final String? fallbackRoute;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        if (fallbackRoute != null) {
          router.goNamed(fallbackRoute!);
          return;
        }
        final now = DateTime.now();
        final last = _lastRootBackPress;
        if (last != null && now.difference(last) < _exitWindow) {
          SystemNavigator.pop();
          return;
        }
        _lastRootBackPress = now;
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
