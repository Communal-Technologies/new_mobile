import 'package:communal_mobile/core/security/token_manager.dart';
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
  NotificationsRepository(this._dioClient, this._tokenManager);

  final DioClient _dioClient;
  final TokenManager _tokenManager;

  /// The cooperative the member has switched to, as a query parameter.
  ///
  /// Resolved here rather than passed in by each caller: the feed, the badge
  /// poller and the push handler all want the same scope, and a screen that
  /// forgot to pass it would quietly show another cooperative's notices under
  /// this one's name.
  ///
  /// Empty when nothing has been selected yet — a fresh install, or a member in
  /// no cooperative. cooperative-svc treats an absent scope as no filter, which
  /// for those two cases is exactly right: they still get the platform's own
  /// notices, and the feed is filtered on their own user id regardless.
  Future<Map<String, dynamic>> _scope() async {
    final active = await _tokenManager.readActiveCooperative();
    final id = active?.cooperativeId ?? '';
    return id.isEmpty ? const {} : {'cooperative_id': id};
  }

  /// Fetch the user's notifications. Pass [unreadOnly] to filter
  /// server-side, e.g. to populate an "Unread" tab.
  Future<NotificationsResult> fetch({bool unreadOnly = false, int limit = 50}) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersNotifications,
        queryParameters: {
          if (unreadOnly) 'status': 'unread',
          'limit': limit,
          ...await _scope(),
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
        queryParameters: await _scope(),
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

  /// Scoped like the feed: "mark all read" means the list on screen.
  Future<void> markAllAsRead() async {
    try {
      await _dioClient.post(
        ApiEndpoints.membersNotificationsMarkAllRead,
        queryParameters: await _scope(),
      );
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
