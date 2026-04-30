import 'dart:convert';

import 'package:communal_mobile/core/navigation/root_navigator_key.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
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
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
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
        android: AndroidInitializationSettings('@drawable/ic_stat_notification'),
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
              _routeFromData(raw);
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
      debugPrint('PushNotificationService: local notifications init skipped: $e');
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
      _routeFromData(message.data);
    });

    // System tray tap that launched the app from terminated — the
    // initial message is replayed once on first read.
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial != null) {
        // Defer to the next frame so the router has actually mounted
        // before we try to push onto it.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _routeFromData(initial.data);
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
  /// Receipt payloads include `trx_reference`, but the receipt screen
  /// currently demands a fully hydrated [TransactionDetailsData]
  /// `extra` (no by-id fetch endpoint yet on mobile). Until that
  /// endpoint lands we drop the user on transaction history — they
  /// can find the row by reference there. TODO: when
  /// `getTransactionByReference` is wired, jump straight to receipt
  /// with the right `extra`.
  static void _routeFromData(Map<String, dynamic> data) {
    final route = (data['route']?.toString() ?? '').trim();
    if (route.isEmpty) return;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    switch (route) {
      case 'transaction-receipt':
        try {
          ctx.goNamed('transaction-history');
        } catch (_) {
          // route name may differ at the time this fires (router
          // not in a state that accepts goNamed). Swallow — no
          // navigation is better than a crash on a notification tap.
        }
        break;
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
