import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/notification_model.dart';
import 'package:communal_mobile/data/models/notification_preferences.dart';
import 'package:dio/dio.dart';

class NotificationsResult {
  NotificationsResult({required this.notifications, required this.unreadCount});

  final List<NotificationModel> notifications;
  final int unreadCount;
}

class NotificationsRepository {
  NotificationsRepository(this._dioClient);

  final DioClient _dioClient;

  /// Fetch the user's notifications. Pass [unreadOnly] to filter
  /// server-side, e.g. to populate an "Unread" tab.
  Future<NotificationsResult> fetch({bool unreadOnly = false, int limit = 50}) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersNotifications,
        queryParameters: {
          if (unreadOnly) 'status': 'unread',
          'limit': limit,
        },
      );
      final body = response.data;
      if (body is Map) {
        final raw = body['data'];
        final list = raw is List
            ? raw
                .whereType<Map>()
                .map((e) => NotificationModel.fromJson(
                      Map<String, dynamic>.from(e),
                    ))
                .toList()
            : <NotificationModel>[];
        final unread =
            int.tryParse(body['unread_count']?.toString() ?? '') ?? 0;
        return NotificationsResult(notifications: list, unreadCount: unread);
      }
      return NotificationsResult(notifications: const [], unreadCount: 0);
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Lightweight badge poll. Returns 0 on failure rather than surfacing
  /// — a missing badge is better than crashing the home screen.
  Future<int> unreadCount() async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersNotificationsUnreadCount,
      );
      final body = response.data;
      if (body is Map) {
        return int.tryParse(body['unread_count']?.toString() ?? '') ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markAsRead(String id) async {
    try {
      await _dioClient.post(ApiEndpoints.membersNotificationRead(id));
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _dioClient.post(ApiEndpoints.membersNotificationsMarkAllRead);
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Per-user notification channel preferences (push/email/sms +
  /// category gates). Backend returns the row keyed on user_id, or
  /// the defaults when the user hasn't saved any yet.
  Future<NotificationPreferences> fetchPreferences() async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersNotificationPreferences,
      );
      final body = response.data;
      if (body is Map && body['data'] is Map) {
        return NotificationPreferences.fromJson(
          Map<String, dynamic>.from(body['data'] as Map),
        );
      }
      return const NotificationPreferences();
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Patches just the changed fields. Backend route is PUT but the
  /// validator only requires the keys you actually send (`sometimes`
  /// rule), so per-toggle saves stay cheap.
  Future<NotificationPreferences> updatePreferences(
    Map<String, dynamic> changes,
  ) async {
    try {
      final response = await _dioClient.put(
        ApiEndpoints.membersNotificationPreferences,
        data: changes,
      );
      final body = response.data;
      if (body is Map && body['data'] is Map) {
        return NotificationPreferences.fromJson(
          Map<String, dynamic>.from(body['data'] as Map),
        );
      }
      throw Exception('Unexpected response from server.');
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  String _messageFromDio(DioException e) {
    final response = e.response;
    if (response == null) return 'Network error. Please check your connection.';
    final data = response.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return 'Unable to load notifications.';
  }
}
