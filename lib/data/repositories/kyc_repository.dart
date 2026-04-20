import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:dio/dio.dart';

class KycRepository {
  KycRepository(this._dioClient);

  final DioClient _dioClient;

  /// Step 1: create Anchor customer + persist profile. Returns Anchor `customer_id`.
  Future<String> registerProfile({
    required String userId,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response =
          await _dioClient.post('/compliance/register/$userId', data: body);
      final data = response.data;
      if (data is Map &&
          (data['status'] == true || data['status'] == 'true')) {
        final id = data['customer_id']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
      throw Exception(
        data is Map ? (data['message']?.toString() ?? 'Registration failed') : 'Registration failed',
      );
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Step 2 (BVN): backend waits for Anchor verification; returns Anchor JSON in `data` on success.
  Future<Map<String, dynamic>?> upgradeToTier1({
    required String anchorCustomerId,
    required String bvn,
    required String dateOfBirth,
    required String gender,
  }) async {
    try {
      final response = await _dioClient.post(
        '/compliance/upgrade-to-tier1/$anchorCustomerId',
        data: <String, dynamic>{
          'bvn': bvn,
          'date_of_birth': dateOfBirth,
          'gender': gender,
        },
      );
      final data = response.data;
      if (data is Map &&
          (data['status'] == true || data['status'] == 'true')) {
        final inner = data['data'];
        if (inner is Map) {
          return Map<String, dynamic>.from(inner);
        }
        return null;
      }
      throw Exception(
        data is Map
            ? (data['message']?.toString() ?? 'BVN verification failed')
            : 'BVN verification failed',
      );
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
      final errors = data['errors'];
      if (errors is Map) {
        final parts = <String>[];
        for (final entry in errors.entries) {
          final v = entry.value;
          if (v is List && v.isNotEmpty) {
            parts.add(v.first.toString());
          } else if (v != null) {
            parts.add(v.toString());
          }
        }
        if (parts.isNotEmpty) return parts.join(' ');
      }
    }
    return e.message ?? 'Request failed';
  }
}
