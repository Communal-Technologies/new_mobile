import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Registers the current device for backend push notifications (FCM token -> profile.device_token).
///
/// This service is resilient by design:
/// - If Firebase is not configured on a build variant, it logs and no-ops.
/// - Token refresh events are listened to and synced to backend.
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;
  String? _lastSyncedToken;

  Future<void> initializeAndSync(AuthRepository authRepository) async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    try {
      // If firebase options / google-services are absent for a build, this may throw.
      // We do not want auth flow to crash because push is optional.
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

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
      debugPrint('PushNotificationService: Firebase init/sync skipped: $e');
    }
  }

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
