import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/obligation_category.dart';
import 'package:dio/dio.dart';

class ObligationCategoriesRepository {
  ObligationCategoriesRepository(this._dioClient);

  final DioClient _dioClient;

  Future<List<ObligationCategory>> fetchForCooperative(String cooperativeId) async {
    try {
      final response = await _dioClient.get(
        '/cooperative/obligation-categories/$cooperativeId',
      );
      final data = response.data;
      if (data is! Map) return const [];
      final list = data['categories'];
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => ObligationCategory.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } on DioException catch (e) {
      final d = e.response?.data;
      if (d is Map && d['message'] != null) {
        throw Exception(d['message'].toString());
      }
      throw Exception('Unable to fetch obligation categories');
    }
  }
}
