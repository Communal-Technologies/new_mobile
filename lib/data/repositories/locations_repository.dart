import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/lga_model.dart';
import 'package:communal_mobile/data/models/state_model.dart';

class LocationsRepository {
  LocationsRepository(this._dioClient);

  final DioClient _dioClient;

  /// When [countryIso] is set (e.g. from the selected cooperative region), only
  /// states for that country are returned. Must match backend `states.country_iso`.
  Future<List<StateModel>> fetchStates({String? countryIso}) async {
    final query = <String, dynamic>{};
    if (countryIso != null && countryIso.length == 2) {
      query['country_iso'] = countryIso.toUpperCase();
    }
    final response = await _dioClient.get(
      '/fetch-states',
      queryParameters: query.isEmpty ? null : query,
      requireAuth: false,
    );
    final data = response.data;
    if (data is! Map) return [];
    final raw = data['states'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => StateModel.fromJson(Map<String, dynamic>.from(e)))
        .where((s) => s.id > 0 && s.name.isNotEmpty)
        .toList();
  }

  /// Authenticated.
  Future<List<LgaModel>> fetchLgas(String stateId) async {
    final response = await _dioClient.get('/fetch-lgas/$stateId');
    final data = response.data;
    if (data is! Map) return [];
    final raw = data['lgas'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => LgaModel.fromJson(Map<String, dynamic>.from(e)))
        .where((l) => l.name.isNotEmpty)
        .toList();
  }
}
