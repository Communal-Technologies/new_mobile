import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:dio/dio.dart';

class CommunityJoinResult {
  CommunityJoinResult({
    required this.cooperativeId,
    required this.cooperativeName,
    required this.ledgerNumber,
    required this.isDefault,
  });

  final String cooperativeId;
  final String cooperativeName;
  final String ledgerNumber;
  final bool isDefault;

  factory CommunityJoinResult.fromJson(Map<String, dynamic> json) {
    return CommunityJoinResult(
      cooperativeId: json['cooperative_id']?.toString() ?? '',
      cooperativeName: json['cooperative_name']?.toString() ?? '',
      ledgerNumber: json['ledger_number']?.toString() ?? '',
      isDefault: json['is_default'] == true,
    );
  }
}

/// Joins / membership operations against a cooperative from the member side.
class CommunityRepository {
  CommunityRepository(this._dioClient);

  final DioClient _dioClient;

  /// Redeem a single-use invite code. Throws [Exception] with a
  /// human-readable message on validation failures so the bottom-sheet
  /// can surface it inline. On success the backend has linked the user
  /// to the cooperative; the caller is expected to refresh auth state
  /// (via [AuthRefreshUserRequested]) so navigation gates re-evaluate.
  Future<CommunityJoinResult> redeemInviteCode(String code) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.membersRedeemInviteCode,
        data: {'code': code.trim().toUpperCase()},
      );

      if (response.statusCode == 200 && response.data is Map) {
        final body = response.data as Map<String, dynamic>;
        final data = body['data'];
        if (data is Map) {
          return CommunityJoinResult.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
      }
      throw Exception('Unexpected response from server.');
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  String _messageFromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      return 'Network error. Please check your connection.';
    }
    final data = response.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    } else if (data is String && data.isNotEmpty) {
      return data;
    }
    switch (response.statusCode) {
      case 404:
        return 'Invite code not found.';
      case 409:
        return 'You are already a member of this cooperative.';
      case 410:
        return 'This invite code is no longer valid.';
      case 422:
        return 'Cooperative cannot accept new members at this time.';
      default:
        return 'Unable to redeem invite code. Please try again.';
    }
  }
}
