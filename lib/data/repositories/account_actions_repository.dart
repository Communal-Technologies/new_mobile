import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:dio/dio.dart';

/// "Big switches" the user pulls on their own account from My Profile —
/// freeze, request-unfreeze, account-closure submit. Each method is a
/// thin wrapper around the existing backend endpoints; the screens use
/// these so PIN-verify + state mutation live in one place per action.
class AccountActionsRepository {
  AccountActionsRepository(this._dioClient);

  final DioClient _dioClient;

  /// Verify the user's transaction PIN. Throws on incorrect / locked /
  /// frozen with a backend-provided message. Used by the freeze /
  /// delete account flows as a PIN gate before mutating state.
  Future<void> verifySecurityPin(String pin) async {
    try {
      await _dioClient.post(
        ApiEndpoints.membersVerifySecurityPin,
        data: {'security_pin': pin},
      );
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Server truth for the wallet's freeze state. The PIN gate rejects every
  /// call with 403 ACCOUNT_FROZEN once a wallet is frozen, so the freeze
  /// screen has to read this before offering the action rather than letting
  /// the user reach the PIN step and fail there.
  Future<FreezeStatus> fetchFreezeStatus() async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersAccountFreezeStatus,
      );
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is Map) {
        return FreezeStatus.fromJson(Map<String, dynamic>.from(data));
      }
      return const FreezeStatus();
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Self-freeze the user's wallet. Backend requires a [reason] string
  /// of at least 10 characters (validated server-side).
  Future<void> freezeAccount(String reason) async {
    try {
      await _dioClient.post(
        ApiEndpoints.membersAccountFreeze,
        data: {'reason': reason},
      );
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Submit an account-closure request. The cooperative admin reviews
  /// and approves/declines — closure is not instant. [reason] is
  /// optional; backend currently accepts the request without one.
  ///
  /// Closure is per-cooperative: a member of several cooperatives leaves
  /// one at a time, so [cooperativeId] identifies which membership is
  /// being closed and the backend resolves the ledger from it.
  Future<void> submitAccountClosure({
    required String cooperativeId,
    String? reason,
  }) async {
    final cooperative = cooperativeId.trim();
    if (cooperative.isEmpty) {
      throw Exception('No cooperative selected.');
    }
    try {
      await _dioClient.post(
        ApiEndpoints.membersAccountClosureSubmit,
        data: {
          'cooperative': cooperative,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
      );
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
      // Laravel validation errors arrive as { errors: { reason: ['...'] } }
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
    }
    return 'Unable to complete request.';
  }
}

/// Wallet freeze state as reported by `GET members/account/freeze-status`.
class FreezeStatus {
  const FreezeStatus({
    this.isFrozen = false,
    this.isSelfFrozen = false,
    this.frozenReason,
  });

  final bool isFrozen;
  final bool isSelfFrozen;
  final String? frozenReason;

  factory FreezeStatus.fromJson(Map<String, dynamic> json) {
    bool flag(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
    final reason = json['frozen_reason']?.toString().trim();
    return FreezeStatus(
      isFrozen:
          flag(json['is_frozen']) ||
          json['account_status']?.toString().trim() == '2',
      isSelfFrozen: flag(json['is_self_frozen']),
      frozenReason: (reason == null || reason.isEmpty) ? null : reason,
    );
  }
}
