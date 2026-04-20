import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/community_membership_model.dart';
import 'package:dio/dio.dart';

class CommunitySettingsRepository {
  CommunitySettingsRepository(this._dioClient);

  final DioClient _dioClient;

  Future<List<CommunityMembership>> fetchMemberships() async {
    try {
      final response = await _dioClient.get('/members/community-settings');
      final data = response.data;
      if (data is! Map) {
        throw Exception('Invalid response');
      }
      final raw = data['memberships'];
      if (raw is! List) {
        return [];
      }
      return raw
          .map((e) => CommunityMembership.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .where((m) => m.cooperativeId.isNotEmpty)
          .toList();
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  Future<CommunityCooperativeSettings> updateSettings(
    String cooperativeId,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _dioClient.put(
        '/members/community-settings/$cooperativeId',
        data: body,
      );
      final data = response.data;
      if (data is! Map) {
        throw Exception('Invalid response');
      }
      final settingsRaw = data['settings'];
      if (settingsRaw is! Map) {
        throw Exception('Missing settings in response');
      }
      return CommunityCooperativeSettings.fromJson(
        Map<String, dynamic>.from(settingsRaw),
      );
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  String _messageFromDio(DioException e) {
    final d = e.response?.data;
    if (d is Map && d['message'] != null) {
      return d['message'].toString();
    }
    return e.message ?? 'Request failed';
  }
}
