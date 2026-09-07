import 'dart:async';

import 'package:flutter/material.dart';

import 'package:communal_mobile/core/navigation/root_navigator_key.dart';
import 'package:communal_mobile/core/update/app_update_service.dart';

/// Runs the store check at launch and on every resume, and turns the answer
/// into the one piece of UI it needs.
///
/// Sits inside `MaterialApp.router`'s builder next to [ConnectivityListener],
/// which is above the router's Navigator — hence [rootNavigatorKey] for the
/// dialog, the same way [SecurityWrapper] reaches it for the idle prompt. That
/// key being null also means the lock screen is up, and the check is skipped
/// entirely rather than popping Play's consent sheet over a PIN entry.
class AppUpdateWatcher extends StatefulWidget {
  const AppUpdateWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<AppUpdateWatcher> createState() => _AppUpdateWatcherState();
}

class _AppUpdateWatcherState extends State<AppUpdateWatcher>
    with WidgetsBindingObserver {
  /// Cold start is already carrying Firebase, the router redirect and the PIN
  /// gate; the store can wait until all of that has settled.
  static const Duration _startupDelay = Duration(seconds: 4);
  static const Duration _resumeCooldown = Duration(minutes: 30);

  DateTime? _lastCheck;
  bool _running = false;
  bool _noticeShowing = false;
  Timer? _startupTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startupTimer = Timer(_startupDelay, _check);
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastCheck;
    if (last != null && DateTime.now().difference(last) < _resumeCooldown) return;
    _check();
  }

  Future<void> _check() async {
    if (_running || _noticeShowing) return;
    if (rootNavigatorKey.currentContext == null) return;

    _running = true;
    _lastCheck = DateTime.now();
    try {
      final outcome = await AppUpdateService.check();
      if (!mounted) return;
      switch (outcome) {
        case AppUpdateOutcome.readyToInstall:
          _showRelaunchPrompt();
        case AppUpdateOutcome.storeUpdateAvailable:
          await _showStorePrompt();
        case AppUpdateOutcome.declined:
        case AppUpdateOutcome.downloading:
        case AppUpdateOutcome.none:
          break;
      }
    } finally {
      _running = false;
    }
  }

  void _showRelaunchPrompt() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: const Text(
          'A new version of Communal is ready. Relaunch to finish updating.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        duration: const Duration(seconds: 12),
        action: SnackBarAction(
          label: 'Relaunch',
          textColor: Colors.white,
          onPressed: AppUpdateService.installDownloaded,
        ),
      ),
    );
  }

  Future<void> _showStorePrompt() async {
    final navContext = rootNavigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;

    _noticeShowing = true;
    try {
      final update = await showDialog<bool>(
        context: navContext,
        builder: (context) => AlertDialog(
          title: const Text('Update available'),
          content: const Text(
            'A newer version of Communal is on the store. Updating keeps your '
            'account on the latest security fixes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              child: const Text('Update'),
            ),
          ],
        ),
      );
      if (update == true) await AppUpdateService.openStore();
    } finally {
      _noticeShowing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
