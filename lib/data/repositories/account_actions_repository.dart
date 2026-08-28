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
  /// [intent] is what the verification may be spent on. These flows are not
  /// payments, so they take `account-action`, which no money route accepts: a PIN
  /// entered to freeze an account used to be spendable on a transfer.
  Future<void> verifySecurityPin(String pin, {required String intent}) async {
    try {
      await _dioClient.post(
        ApiEndpoints.membersVerifySecurityPin,
        data: {'security_pin': pin, 'intent': intent},
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

  /// What leaving [cooperativeId] would cost, and whether it can be asked for
  /// at all. Read before the confirmation screen so the member decides against
  /// the same figures the administrator will review.
  Future<AccountClosurePreview> fetchAccountClosurePreview(
    String cooperativeId,
  ) async {
    final cooperative = cooperativeId.trim();
    if (cooperative.isEmpty) {
      throw Exception('No cooperative selected.');
    }
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersAccountClosurePreview,
        queryParameters: {'cooperative': cooperative},
      );
      final body = response.data;
      final preview = body is Map ? body['preview'] : null;
      if (preview is Map) {
        return AccountClosurePreview.fromJson(
          Map<String, dynamic>.from(preview),
        );
      }
      throw Exception('The server returned no closure preview.');
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

/// What `GET members/account-closure/preview` says about leaving one cooperative.
///
/// [blockers] are refusals the server will repeat if the member submits anyway,
/// so an empty list is [canSubmit]. [warnings] are not refusals — whether a
/// member carrying debt may leave is the cooperative's decision, taken when an
/// administrator reviews the request — so the app shows them as things to
/// acknowledge, never as a dead end.
class AccountClosurePreview {
  const AccountClosurePreview({
    this.ledgerNumber = '',
    this.loansBalance = 0,
    this.interestBalance = 0,
    this.finesBalance = 0,
    this.epcBalance = 0,
    this.netAmount = 0,
    this.netType = 'balanced',
    this.hasPending = false,
    this.loansGuaranteed = 0,
    this.canSubmit = false,
    this.blockers = const [],
    this.warnings = const [],
  });

  final String ledgerNumber;
  final int loansBalance;
  final int interestBalance;
  final int finesBalance;
  final int epcBalance;
  final int netAmount;
  final String netType;
  final bool hasPending;
  final int loansGuaranteed;
  final bool canSubmit;
  final List<String> blockers;
  final List<String> warnings;

  int get totalDebt => loansBalance + interestBalance + finesBalance;

  factory AccountClosurePreview.fromJson(Map<String, dynamic> json) {
    int whole(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);
    List<String> lines(dynamic v) => v is List
        ? v.map((e) => e.toString()).where((e) => e.isNotEmpty).toList()
        : const <String>[];

    final snapshot = json['snapshot'] is Map
        ? Map<String, dynamic>.from(json['snapshot'] as Map)
        : const <String, dynamic>{};

    return AccountClosurePreview(
      ledgerNumber: json['ledger_number']?.toString() ?? '',
      loansBalance: whole(snapshot['loans_balance']),
      interestBalance: whole(snapshot['interest_balance']),
      finesBalance: whole(snapshot['fines_balance']),
      epcBalance: whole(snapshot['epc_balance']),
      netAmount: whole(snapshot['net_amount']),
      netType: snapshot['net_type']?.toString() ?? 'balanced',
      hasPending: json['has_pending'] == true,
      loansGuaranteed: whole(json['loans_guaranteed']),
      canSubmit: json['can_submit'] == true,
      blockers: lines(json['blockers']),
      warnings: lines(json['warnings']),
    );
  }
}
