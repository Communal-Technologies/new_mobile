import 'dart:async';
import 'dart:convert';

import 'package:communal_mobile/core/navigation/root_navigator_key.dart';
import 'package:communal_mobile/core/services/pending_deep_link_service.dart';
import 'package:communal_mobile/core/services/unread_notifications_service.dart';
import 'package:communal_mobile/cubits/security/security_cubit.dart';
import 'package:communal_mobile/data/models/loan_application.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

/// Channel ID referenced by AndroidManifest.xml's
/// `com.google.firebase.messaging.default_notification_channel_id` meta-data.
/// Must match exactly, otherwise Android 8+ silently drops FCM notifications.
const String _fcmChannelId = 'high_importance_channel';
const String _fcmChannelName = 'High Importance Notifications';
const String _fcmChannelDescription =
    'Used for important notifications delivered via Firebase Cloud Messaging.';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// Top-level background handler. MUST be top-level (not a closure or method)
/// because Flutter spins up a fresh isolate for background pushes and needs to
/// resolve this symbol by name. Registered once in main() before runApp().
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background isolate has no access to the main app's Firebase state, so
  // re-initialize. Cheap if already initialized.
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  debugPrint('FCM background message: ${message.messageId}');
}

/// Registers the device for backend push notifications and wires the foreground
/// display channel.
///
/// Resilient by design: if Firebase config is absent on a build variant, calls
/// log and no-op so the auth flow never crashes.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;
  bool _firebaseReady = false;
  String? _lastSyncedToken;

  /// One-shot Firebase + local-notifications + foreground handler setup. Safe
  /// to call from main() before runApp(); does not require a logged-in user.
  static Future<void> initializeForApp() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      debugPrint('PushNotificationService: Firebase.initializeApp skipped: $e');
      return;
    }

    // iOS: surface foreground notifications as banners. No-op on Android.
    try {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    } catch (e) {
      debugPrint('PushNotificationService: foreground options skipped: $e');
    }

    // Local notifications plugin — the bridge for Android foreground display.
    // Use the monochrome status-bar drawable, NOT the colored launcher icon
    // (Android renders the small icon in both the status bar and the
    // notification card; the launcher icon is colored and appears as a
    // white square inside the white expanded notification card).
    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings(
          '@drawable/ic_stat_notification',
        ),
        iOS: DarwinInitializationSettings(),
      );
      await _localNotifications.initialize(
        initSettings,
        // Tap on a notification we showed via the local-notifications
        // plugin (foreground path) — payload is the JSON-encoded
        // RemoteMessage.data block, parse it back and route the same
        // way as a system-tray tap.
        onDidReceiveNotificationResponse: (response) {
          final payload = response.payload;
          if (payload == null || payload.isEmpty) return;
          try {
            final raw = jsonDecode(payload);
            if (raw is Map<String, dynamic>) {
              unawaited(_routeFromData(raw));
            }
          } catch (_) {
            // Older payloads were `Map.toString()` not JSON; ignore.
          }
        },
      );

      const channel = AndroidNotificationChannel(
        _fcmChannelId,
        _fcmChannelName,
        description: _fcmChannelDescription,
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    } catch (e) {
      debugPrint(
        'PushNotificationService: local notifications init skipped: $e',
      );
    }

    // Foreground listener: when a notification-payload message arrives while
    // the app is open, mirror it through the local-notifications channel so
    // Android shows it (iOS handles via setForegroundNotificationPresentationOptions).
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = notification?.android;
      if (notification == null || android == null) {
        return;
      }
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _fcmChannelId,
            _fcmChannelName,
            channelDescription: _fcmChannelDescription,
            icon: android.smallIcon ?? '@drawable/ic_stat_notification',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data.isEmpty ? null : jsonEncode(message.data),
      );
    });

    // System tray tap while the app is backgrounded — Android delivers
    // the RemoteMessage straight to onMessageOpenedApp.
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(_routeFromData(message.data));
    });

    // System tray tap that launched the app from terminated — the
    // initial message is replayed once on first read.
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        // Defer to the next frame so the router has actually mounted
        // before we try to push onto it.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_routeFromData(initial.data));
        });
      }
    } catch (_) {
      // No initial message / Firebase config absent → no-op.
    }
  }

  /// Translate a notification's `data` block into a navigation. Today
  /// the only `route` we mint server-side is `transaction-receipt`;
  /// extend the switch as more push types start carrying a route hint.
  ///
  /// Translate an FCM data block into a route intent and navigate.
  ///
  /// Backend convention (see `ProcessPushNotifications::handle` —
  /// every caller-supplied data key is forwarded verbatim into the
  /// FCM data block):
  ///
  ///   type='guarantor_loan_approval'
  ///       carries `loan_ref`, `notification_id`. Tap → guarantor
  ///       requests screen.
  ///
  ///   type='transaction-receipt' (legacy `route` key still respected)
  ///       carries `trx_reference`. The receipt screen needs a
  ///       hydrated TransactionDetailsData `extra` and we don't
  ///       have a by-id fetch yet — drop on transaction-history,
  ///       same as before. TODO: jump to receipt when the by-id
  ///       fetch is wired.
  ///
  /// When the SecurityCubit has the app locked, `goNamed` is a no-op
  /// because the locked overlay replaces the entire MaterialApp.
  /// Stash the intent in [PendingDeepLinkService]; the security
  /// wrapper consumes it on unlock. Same logic also handles the
  /// cold-start case where the user tapped a push from the system
  /// tray and Firebase replays it before our app fully comes up.
  static Future<void> _routeFromData(Map<String, dynamic> data) async {
    // Refresh the unread-count badge optimistically — a push usually
    // means a new in-app row landed. Cheap on success, no-op on err.
    try {
      // Don't await — the badge is decorative; routing is the priority.
      // ignore: unawaited_futures
      getIt<UnreadNotificationsService>().refresh();
    } catch (_) {
      /* ignore — service may not be registered in tests */
    }

    final intent = await _intentForData(data);
    if (intent == null) return;

    final ctx = rootNavigatorKey.currentContext;
    final pending = (() {
      try {
        return getIt<PendingDeepLinkService>();
      } catch (_) {
        return null;
      }
    })();

    bool locked = false;
    if (ctx != null) {
      try {
        // Safe across the await above — the root navigator's context
        // outlives the push handler and isn't owned by any State.
        // ignore: use_build_context_synchronously
        locked = ctx.read<SecurityCubit>().state == SecurityState.locked;
      } catch (_) {
        // Cubit not in scope (e.g. during cold start before runApp's
        // tree mounts). Treat as locked-ish so the intent gets
        // queued and replayed once the tree is ready.
        locked = true;
      }
    }

    if (ctx == null || locked) {
      pending?.store(intent);
      return;
    }

    try {
      // Same root-navigator-context rationale as above.
      // ignore: use_build_context_synchronously
      ctx.goNamed(intent.routeName, extra: intent.extra);
    } catch (_) {
      // Router refused (mid-rebuild or unknown route) — fall back to
      // queuing so the next safe moment can replay.
      pending?.store(intent);
    }
  }

  /// Resolve a deep-link intent from a stored in-app notification's
  /// `data` payload. Shares the exact routing + hydration logic used
  /// for push taps so the Notifications screen navigates identically.
  /// Returns null when the payload carries no actionable type.
  static Future<DeepLinkIntent?> resolveIntent(
    Map<String, dynamic> data,
  ) => _intentForData(data);

  /// Async because some types need to hydrate a model from the
  /// backend (loan-detail expects a fully built [LoanApplication] in
  /// `extra`, not just an id). The unlock replay path stashes a
  /// resolved intent rather than the raw data block, so the fetch
  /// only happens once per tap regardless of how many lock cycles
  /// it survives.
  static Future<DeepLinkIntent?> _intentForData(
    Map<String, dynamic> data,
  ) async {
    final type = (data['type']?.toString() ?? '').trim();
    final legacyRoute = (data['route']?.toString() ?? '').trim();

    if (type == 'guarantor_loan_approval') {
      // No id-based hydration needed — the guarantor-requests screen
      // fetches its own list. Mobile marks the source notification
      // read once the guarantor approves / declines from there.
      return const DeepLinkIntent(routeName: 'guarantor-requests');
    }

    // Loan-typed pushes (rejected guarantor, status change, repayment
    // reminders, …) carry `loan_id`. Hydrate the LoanApplication so
    // the detail route gets a fully-built model in `extra`. If the
    // fetch fails or no id is present, fall through to the loans hub.
    if (type == 'loan' ||
        type == 'loan_status' ||
        type == 'loan_guarantor_rejected' ||
        type == 'loan_guarantor_approved' ||
        type == 'loan_guarantor_declined' ||
        type == 'loan_guarantor_expired' ||
        type == 'loan_guarantor_event' ||
        type == 'loan_repayment') {
      final loanId = (data['loan_id']?.toString() ?? '').trim();
      if (loanId.isNotEmpty) {
        try {
          final loan = await getIt<LoanRepository>().fetchLoanById(loanId);
          if (loan != null) {
            return DeepLinkIntent(
              routeName: 'loan-detail',
              extra: <String, dynamic>{'loan': loan},
            );
          }
        } catch (_) {
          // Fetch failed (offline, 404, auth refresh in progress) —
          // dropping on the loans hub is more useful than a crash.
        }
      }
      return const DeepLinkIntent(routeName: 'loans');
    }

    // Obligation-typed pushes carry `obligation_id`. Hydrate the
    // FinancialObligation + its InternalAccount via the by-id
    // endpoint and route to obligation-detail. Falls back to the
    // obligations hub when the id is missing or the fetch fails.
    if (type == 'obligation' ||
        type == 'obligation_payment' ||
        type == 'obligation_status') {
      final obligationId = (data['obligation_id']?.toString() ?? '').trim();
      if (obligationId.isNotEmpty) {
        try {
          final obligation = await getIt<MemberObligationsRepository>()
              .fetchObligationById(obligationId);
          if (obligation != null) {
            return DeepLinkIntent(
              routeName: 'obligation-detail',
              extra: obligation,
            );
          }
        } catch (_) {
          /* fall through */
        }
      }
      return const DeepLinkIntent(routeName: 'obligations');
    }

    if (type == 'transaction' ||
        type == 'transaction-receipt' ||
        legacyRoute == 'transaction-receipt') {
      // Backend pushes carry the trx reference under any of these
      // keys depending on origin (transfer initiate vs. webhook
      // settlement vs. obligation/loan record-only). Try them in
      // order — first non-empty wins.
      final ref =
          (data['transaction_reference']?.toString() ?? '').trim().isNotEmpty
          ? data['transaction_reference']!.toString().trim()
          : (data['trx_reference']?.toString() ?? '').trim().isNotEmpty
          ? data['trx_reference']!.toString().trim()
          : (data['external_reference']?.toString() ?? '').trim();
      if (ref.isNotEmpty) {
        try {
          final details = await getIt<TransferRepository>()
              .fetchTransactionByReference(ref, currencySymbol: '₦');
          if (details != null) {
            return DeepLinkIntent(
              routeName: 'transaction-details',
              extra: details,
            );
          }
        } catch (_) {
          /* fall through */
        }
      }
      return const DeepLinkIntent(routeName: 'transaction-history');
    }

    // Unknown / generic push: drop the user on the in-app list so
    // they can read the message and follow up if needed.
    return const DeepLinkIntent(routeName: 'notifications');
  }

  /// Replay a pending deep-link AFTER the app finishes any in-progress
  /// unlock step. Wired into the SecurityCubit listener in main /
  /// security_wrapper. Safe to call when no intent is pending (no-op).
  static void replayPendingDeepLink() {
    final pending = (() {
      try {
        return getIt<PendingDeepLinkService>();
      } catch (_) {
        return null;
      }
    })();
    final intent = pending?.consume();
    if (intent == null) return;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    try {
      ctx.goNamed(intent.routeName, extra: intent.extra);
    } catch (_) {
      /* swallow — better no nav than a crash on resume */
    }
  }

  /// Permission prompt + token sync to backend. Called after auth.
  Future<void> initializeAndSync(AuthRepository authRepository) async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    try {
      // initializeForApp() should have run from main() already; double-check
      // here so direct callers still work in tests / scripts.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseReady = true;
    } catch (e) {
      debugPrint('PushNotificationService: Firebase init/sync skipped: $e');
      return;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final token = await messaging.getToken();
      await _syncToken(authRepository, token);

      FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
        await _syncToken(authRepository, token);
      });
    } catch (e) {
      debugPrint('PushNotificationService: token sync skipped: $e');
    }
  }

  bool get firebaseReady => _firebaseReady;

  Future<void> _syncToken(AuthRepository authRepository, String? token) async {
    final t = token?.trim();
    if (t == null || t.isEmpty) {
      return;
    }
    if (_lastSyncedToken == t) {
      return;
    }
    try {
      await authRepository.updateDeviceToken(t);
      _lastSyncedToken = t;
    } catch (e) {
      debugPrint('PushNotificationService: token sync failed: $e');
    }
  }
}
