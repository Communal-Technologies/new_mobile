import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/constants/constants.dart';
import 'package:communal_mobile/cubits/server_status/server_status_cubit.dart';

/// Blocking dialog shown while [ServerStatusCubit] is `down` post-splash.
///
/// Mirrors the dashboard's `ServerDownGuard`:
///  - polls a cheap public endpoint every [_pingInterval];
///  - dismisses itself when the ping returns *any* HTTP response (even
///    4xx — the network path is alive, that's all we care about);
///  - after [_watchdog] of failed pings, gives up and force-logs the
///    user out so the next session starts clean.
///
/// We intentionally avoid showing this during the splash flow — the
/// splash has its own "no internet / can't reach server" UX. The overlay
/// gates rendering on [AuthBloc] having reached a *resolved* state
/// (`AuthAuthenticated` / `AuthUnauthenticated` / `AuthFailure`); before
/// that, the splash owns the screen.
class ServerStatusOverlay extends StatefulWidget {
  const ServerStatusOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<ServerStatusOverlay> createState() => _ServerStatusOverlayState();
}

class _ServerStatusOverlayState extends State<ServerStatusOverlay> {
  /// Poll interval while down. Same cadence as the dashboard.
  static const Duration _pingInterval = Duration(seconds: 5);

  /// Per-ping timeout — kept short so the loop stays responsive.
  static const Duration _pingTimeout = Duration(seconds: 4);

  /// Give up after this and force the user back to the welcome screen.
  static const Duration _watchdog = Duration(minutes: 10);

  /// Bare Dio so the ping path never re-enters [ServerStatusInterceptor]
  /// (a recovery ping should never re-flag the cubit it's trying to
  /// clear).
  final Dio _pingDio = Dio(BaseOptions(
    baseUrl: AppConstants.baseUrl,
    connectTimeout: _pingTimeout,
    receiveTimeout: _pingTimeout,
    sendTimeout: _pingTimeout,
    // Treat any HTTP response as "transport works" — see [_runPing].
    validateStatus: (_) => true,
  ));

  Timer? _pollTimer;
  Timer? _watchdogTimer;
  bool _dialogOpen = false;
  bool _pingInFlight = false;

  @override
  void dispose() {
    _stopLoops();
    _pingDio.close(force: true);
    super.dispose();
  }

  void _stopLoops() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  void _onStatusChanged(BuildContext context, ServerStatus status) {
    final authState = context.read<AuthBloc>().state;
    final authResolved = authState is AuthAuthenticated ||
        authState is AuthUnauthenticated ||
        authState is AuthFailure;
    // While the splash is still resolving the session, defer to its
    // own error UX. The interceptor still records the down state, so
    // when auth resolves and we're still down, the dialog will open.
    if (!authResolved) return;

    if (status == ServerStatus.down && !_dialogOpen) {
      _openDialog();
    } else if (status == ServerStatus.up && _dialogOpen) {
      _closeDialog();
    }
  }

  Future<void> _openDialog() async {
    _dialogOpen = true;

    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pingInterval, (_) => _runPing());

    _watchdogTimer?.cancel();
    _watchdogTimer = Timer(_watchdog, _onWatchdogElapsed);

    // Show the dialog. `barrierDismissible: false` + WillPopScope (via
    // PopScope on Flutter 3.16+) means the user can't dismiss it.
    // Use the root navigator so the dialog sits over any nested
    // MaterialApp (e.g. the SecurityWrapper lock screen).
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const _ConnectionLostDialog(),
    );
    // showDialog resolves when the dialog pops. Reset state here so a
    // future down-event can re-open.
    _dialogOpen = false;
    _stopLoops();
  }

  void _closeDialog() {
    _stopLoops();
    if (!_dialogOpen) return;
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
    _dialogOpen = false;
  }

  Future<void> _runPing() async {
    if (_pingInFlight) return;
    _pingInFlight = true;
    try {
      final response = await _pingDio.get<dynamic>(AppConstants.configUri);
      // `validateStatus` returns true for everything, so any response —
      // 2xx, 4xx, 5xx — flows into here. Treat *any* response as proof
      // the transport works; only no-response throws below.
      if (response.statusCode != null && mounted) {
        context.read<ServerStatusCubit>().markUp();
      }
    } catch (_) {
      // Still down. Wait for the next tick.
    } finally {
      _pingInFlight = false;
    }
  }

  void _onWatchdogElapsed() {
    if (!mounted) return;
    // Best-effort sign out. The user can re-auth once the backend is
    // healthy; sitting on a stale token for hours is worse.
    try {
      context.read<AuthBloc>().add(LogoutRequested());
    } catch (_) {}
    // Mark up so the dialog tears down. The auth bloc's logout will
    // route to /welcome.
    try {
      context.read<ServerStatusCubit>().markUp();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ServerStatusCubit, ServerStatus>(
      listenWhen: (previous, current) => previous != current,
      listener: _onStatusChanged,
      child: widget.child,
    );
  }
}

class _ConnectionLostDialog extends StatelessWidget {
  const _ConnectionLostDialog();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 44, color: theme.colorScheme.error),
              const SizedBox(height: 14),
              Text(
                'Connection lost',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "We can't reach the server right now. We'll keep trying — please don't close the app.",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(height: 18),
              Text(
                "If we can't reconnect within 10 minutes you'll be signed out.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
