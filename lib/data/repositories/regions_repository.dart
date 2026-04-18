import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/region_model.dart';

class RegionsRepository {
  RegionsRepository(this._dioClient);

  final DioClient _dioClient;

  /// Filled after a successful [fetchRegions]; reused by auth screens unless [forceRefresh].
  List<RegionModel>? _memoryCache;

  /// Public endpoint: active regions for signup / phone defaults.
  Future<List<RegionModel>> fetchRegions({bool forceRefresh = false}) async {
    if (!forceRefresh && _memoryCache != null) {
      return _memoryCache!;
    }

    final response = await _dioClient.get('/fetch-regions');
    final data = response.data;
    if (data is! Map) {
      _memoryCache = [];
      return [];
    }
    final raw = data['regions'];
    if (raw is! List) {
      _memoryCache = [];
      return [];
    }
    final list = raw
        .whereType<Map>()
        .map((e) => RegionModel.fromJson(Map<String, dynamic>.from(e)))
        .where((r) => r.countryIso.length == 2 && r.phoneDialCode.isNotEmpty)
        .toList();
    _memoryCache = list;
    return list;
  }
}
