import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/public_cooperative.dart';
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

/// The caller's own rating for a cooperative (cooperative-svc).
class MemberRating {
  MemberRating({required this.stars, this.review});

  final int stars;
  final String? review;

  factory MemberRating.fromJson(Map<String, dynamic> json) {
    final s = json['stars'];
    final r = json['review']?.toString();
    return MemberRating(
      stars: s is num ? s.toInt() : int.tryParse(s?.toString() ?? '') ?? 0,
      review: (r == null || r.trim().isEmpty) ? null : r.trim(),
    );
  }
}

enum JoinRequestStatus { pending, approved, declined, cancelled, unknown }

JoinRequestStatus _parseStatus(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'pending':
      return JoinRequestStatus.pending;
    case 'approved':
      return JoinRequestStatus.approved;
    case 'declined':
      return JoinRequestStatus.declined;
    case 'cancelled':
      return JoinRequestStatus.cancelled;
    default:
      return JoinRequestStatus.unknown;
  }
}

class CommunityJoinRequest {
  CommunityJoinRequest({
    required this.id,
    required this.cooperativeId,
    required this.cooperativeName,
    required this.message,
    required this.status,
    required this.declineReason,
    required this.decidedAt,
    required this.createdAt,
  });

  final String id;
  final String cooperativeId;
  final String cooperativeName;
  final String? message;
  final JoinRequestStatus status;
  final String? declineReason;
  final DateTime? decidedAt;
  final DateTime? createdAt;

  factory CommunityJoinRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parse(dynamic v) {
      if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
      return null;
    }

    return CommunityJoinRequest(
      id: json['id']?.toString() ?? '',
      cooperativeId: json['cooperative_id']?.toString() ?? '',
      cooperativeName: json['cooperative_name']?.toString() ?? '',
      message: (json['message'] as String?)?.trim().isEmpty == true
          ? null
          : json['message']?.toString(),
      status: _parseStatus(json['status']?.toString()),
      declineReason: json['decline_reason']?.toString(),
      decidedAt: parse(json['decided_at']),
      createdAt: parse(json['created_at']),
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

  /// Submit a request to join a cooperative the user does not have an
  /// invite code for. The cooperative admin reviews and approves or
  /// declines from the dashboard.
  Future<CommunityJoinRequest> requestToJoin({
    required String cooperativeId,
    String? message,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.membersJoinRequests,
        data: {
          'cooperative_id': cooperativeId,
          if (message != null && message.trim().isNotEmpty)
            'message': message.trim(),
        },
      );

      final body = response.data;
      if (body is Map && body['data'] is Map) {
        return CommunityJoinRequest.fromJson(
          Map<String, dynamic>.from(body['data'] as Map),
        );
      }
      throw Exception('Unexpected response from server.');
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// List the user's join requests across all cooperatives. The
  /// application-status screen filters to a specific cooperative.
  Future<List<CommunityJoinRequest>> fetchMyJoinRequests() async {
    try {
      final response = await _dioClient.get(ApiEndpoints.membersJoinRequestsMine);
      final body = response.data;
      if (body is Map && body['data'] is List) {
        return (body['data'] as List)
            .whereType<Map>()
            .map((e) => CommunityJoinRequest.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Cancel a pending request. Approved/declined/cancelled requests
  /// return 409 from the backend; surfaced via [Exception] message.
  Future<void> cancelJoinRequest(String requestId) async {
    try {
      await _dioClient.post(ApiEndpoints.membersJoinRequestCancel(requestId));
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Public cooperatives the user can discover and request to join.
  /// Backend filters to coops with allow_signup=1 and orders featured
  /// first. Endpoint is unauthenticated, but the dio client adds auth
  /// when available — that's fine, the route ignores it.
  Future<List<PublicCooperative>> fetchPublicCooperatives() async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.fetchCooperatives,
        requireAuth: false,
      );
      final body = response.data;
      if (body is Map && body['cooperatives'] is List) {
        return (body['cooperatives'] as List)
            .whereType<Map>()
            .map((e) => PublicCooperative.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .where((c) => c.cooperativeId.isNotEmpty)
            .toList();
      }
      return const [];
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Single cooperative profile, used by the discovery detail screen.
  /// Accepts cooperative_id, unique_id, or the cooperative UUID id.
  Future<PublicCooperative> fetchCooperativeProfile(String id) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.fetchCooperativeProfile(id),
      );
      final body = response.data;
      if (body is Map && body['cooperative'] is Map) {
        return PublicCooperative.fromJson(
          Map<String, dynamic>.from(body['cooperative'] as Map),
        );
      }
      throw Exception('Unexpected response from server.');
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Submit (or update) the caller's 1-5 star rating for a cooperative they
  /// belong to. Owned by cooperative-svc; upserts on (member, cooperative).
  /// 403 when the caller is not a member; 422 on an out-of-range score.
  Future<void> submitRating({
    required String cooperativeId,
    required int stars,
    String? review,
  }) async {
    try {
      await _dioClient.post(
        ApiEndpoints.cooperativeRating(cooperativeId),
        data: {
          'stars': stars,
          if (review != null && review.trim().isNotEmpty)
            'review': review.trim(),
        },
      );
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// The caller's own rating for a cooperative, or null when they have not
  /// rated it yet. Used to pre-fill the rating sheet.
  Future<MemberRating?> fetchMyRating(String cooperativeId) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.cooperativeRatingMine(cooperativeId),
      );
      final body = response.data;
      if (body is Map && body['rating'] is Map) {
        return MemberRating.fromJson(
          Map<String, dynamic>.from(body['rating'] as Map),
        );
      }
      return null;
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  Future<Map<String, String>?> fetchCooperativeStats(String id) async {
    try {
      final response = await _dioClient.get(ApiEndpoints.cooperativeStats(id));
      final body = response.data;
      if (body is Map && body['stats'] is Map) {
        return (body['stats'] as Map)
            .map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
      return null;
    } on DioException {
      return null;
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
