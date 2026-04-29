import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
    try {
      const initSettings = InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      );
      await _localNotifications.initialize(initSettings);

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
            icon: android.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        payload: message.data.isEmpty ? null : message.data.toString(),
      );
    });
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
