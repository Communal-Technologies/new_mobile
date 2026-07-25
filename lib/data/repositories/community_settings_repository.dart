import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/community_membership_model.dart';
import 'package:dio/dio.dart';

class CommunitySettingsRepository {
  CommunitySettingsRepository(this._dioClient);

  final DioClient _dioClient;

  // Memberships change rarely (join / leave a cooperative), so the sidebar
  // shouldn't refetch them every time it's opened. Cache the last successful
  // list and hand it back instantly; callers force a network round-trip via
  // [forceRefresh] (after joining) and drop it via [invalidateMemberships].
  List<CommunityMembership>? _membershipsCache;

  List<CommunityMembership>? get cachedMemberships => _membershipsCache;

  void invalidateMemberships() => _membershipsCache = null;

  Future<List<CommunityMembership>> fetchMemberships(
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _membershipsCache != null) {
      return _membershipsCache!;
    }
    try {
      final response = await _dioClient.get(ApiEndpoints.membersCommunitySettings);
      final data = response.data;
      if (data is! Map) {
        throw Exception('Invalid response');
      }
      final raw = data['memberships'];
      if (raw is! List) {
        return [];
      }
      final seen = <String>{};
      final list = <CommunityMembership>[];
      for (final e in raw) {
        if (e is! Map) continue;
        final m = CommunityMembership.fromJson(Map<String, dynamic>.from(e));
        if (m.cooperativeId.isEmpty) continue;
        // Dedupe by cooperative id — a duplicate membership row would
        // otherwise render as repeated tiles (and, mid-switch, could flicker
        // into showing the same cooperative several times).
        if (!seen.add(m.cooperativeId)) continue;
        list.add(m);
      }
      _membershipsCache = list;
      return list;
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
        ApiEndpoints.membersCommunitySettingsForCooperative(cooperativeId),
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
