import 'package:communal_mobile/core/utils/app_logger.dart';
import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/announcement.dart';
import 'package:dio/dio.dart';

class AnnouncementRepository {
  AnnouncementRepository(this._dioClient);

  static const _tag = 'AnnouncementRepository';
  final DioClient _dioClient;

  /// Announcements this member has not been shown yet. Never throws: an
  /// announcement is not worth blocking the home screen over.
  Future<List<Announcement>> fetch({String? cooperativeId}) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersAnnouncements(cooperativeId),
      );
      final data = response.data;
      final raw = data is Map ? data['announcements'] : null;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Announcement.fromJson(Map<String, dynamic>.from(e)))
          .where((a) => a.id.isNotEmpty && a.imageUrl.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      AppLogger.warn(_tag, 'fetch failed', error: e);
      return const [];
    }
  }

  /// Records that the member has dealt with it, so it is not shown again.
  Future<void> acknowledge(String id, {String outcome = 'seen'}) async {
    try {
      await _dioClient.post(
        ApiEndpoints.membersAcknowledgeAnnouncement(id),
        data: <String, dynamic>{'outcome': outcome},
      );
    } on DioException catch (e) {
      AppLogger.warn(_tag, 'acknowledge failed', error: e);
    }
  }
}
