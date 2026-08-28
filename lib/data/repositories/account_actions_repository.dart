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

  /// The checkpoints standing between the member and deleting their whole
  /// Communal account. Read before the flow starts: the app renders
  /// [AccountDeletionPreview.blockers] as they come and offers the delete only
  /// when [AccountDeletionPreview.canDelete] is true. It never computes any of
  /// this itself — the server re-checks all of it on the delete anyway.
  Future<AccountDeletionPreview> fetchAccountDeletionPreview() async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersAccountDeletionPreview,
      );
      final body = response.data;
      final data = body is Map ? body['data'] : null;
      if (data is Map) {
        return AccountDeletionPreview.fromJson(Map<String, dynamic>.from(data));
      }
      throw Exception('The server returned no deletion preview.');
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Delete the member's whole Communal account. Final, and immediate: on
  /// success the identity is closed and every token the app holds is dead, so
  /// the caller's only remaining job is to sign out locally.
  ///
  /// [confirmation] is the word the member typed. It is sent because the server
  /// checks it too — the typed word is a checkpoint, not screen decoration.
  /// A PIN must have been verified with intent `account-action` just before
  /// this call: the server spends that authorisation here and will not accept a
  /// second attempt on the same one.
  Future<void> deleteAccount({
    required String confirmation,
    String? reason,
  }) async {
    try {
      await _dioClient.post(
        ApiEndpoints.membersAccountDeletion,
        data: {
          'confirmation': confirmation,
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

/// What `GET members/account/deletion/preview` says about deleting the whole
/// Communal account.
///
/// Every entry in [blockers] is a refusal, not something to acknowledge: nobody
/// reviews a deletion, so anything still attached to the account has to be
/// resolved first. Each one carries the [AccountDeletionBlocker.message] the
/// server wrote, which names the door to go through instead — the app must not
/// paraphrase them or invent its own.
class AccountDeletionPreview {
  const AccountDeletionPreview({
    this.canDelete = false,
    this.blockers = const [],
    this.walletBalance = 0,
    this.isFrozen = false,
    this.memberships = const [],
    this.loansOwing = 0,
    this.interestOwing = 0,
    this.finesOwing = 0,
    this.totalOwing = 0,
    this.loansGuaranteed = 0,
    this.purgeAfterDays = 30,
  });

  final bool canDelete;
  final List<AccountDeletionBlocker> blockers;
  final int walletBalance;
  final bool isFrozen;
  final List<String> memberships;
  final int loansOwing;
  final int interestOwing;
  final int finesOwing;
  final int totalOwing;
  final int loansGuaranteed;
  final int purgeAfterDays;

  factory AccountDeletionPreview.fromJson(Map<String, dynamic> json) {
    int whole(dynamic v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

    final memberships = json['memberships'];

    return AccountDeletionPreview(
      canDelete: json['can_delete'] == true,
      blockers: json['blockers'] is List
          ? (json['blockers'] as List)
                .whereType<Map>()
                .map(
                  (e) => AccountDeletionBlocker.fromJson(
                    Map<String, dynamic>.from(e),
                  ),
                )
                .toList()
          : const [],
      walletBalance: whole(json['wallet_balance']),
      isFrozen: json['is_frozen'] == true,
      memberships: memberships is List
          ? memberships
                .whereType<Map>()
                .map(
                  (e) =>
                      (e['name'] ?? e['cooperative_id'] ?? '')
                          .toString()
                          .trim(),
                )
                .where((e) => e.isNotEmpty)
                .toList()
          : const <String>[],
      loansOwing: whole(json['loans_owing']),
      interestOwing: whole(json['interest_owing']),
      finesOwing: whole(json['fines_owing']),
      totalOwing: whole(json['total_owing']),
      loansGuaranteed: whole(json['loans_guaranteed']),
      purgeAfterDays: json['purge_after_days'] == null
          ? 30
          : whole(json['purge_after_days']),
    );
  }
}

/// One reason the account cannot be deleted yet. [code] is for the app to key
/// an icon or a shortcut off; [message] is what the member reads.
class AccountDeletionBlocker {
  const AccountDeletionBlocker({required this.code, required this.message});

  final String code;
  final String message;

  factory AccountDeletionBlocker.fromJson(Map<String, dynamic> json) =>
      AccountDeletionBlocker(
        code: json['code']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
      );
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
