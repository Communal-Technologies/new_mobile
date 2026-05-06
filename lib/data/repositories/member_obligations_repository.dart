import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:dio/dio.dart';

/// Backend stores [Ledger.destination] as `{AccountType}-{account_code}`
/// (e.g. `Equity-IA…`) for the credit row and (after the obligation→
/// obligation fix) `obligation-{account_code}` (lowercase) for the debit
/// row that hangs off the source obligation. Both cases are covered here.
bool _ledgerRowMatchesObligation(
  Map<String, dynamic> row,
  Obligation obligation,
) {
  final code = obligation.accountCode.trim();
  if (code.isEmpty) return false;

  final dest = row['destination']?.toString().trim() ?? '';
  if (dest.isNotEmpty) {
    const prefixes = [
      'Equity',
      'Patronage',
      'Custom',
      'Obligation',
      'obligation',
    ];
    for (final p in prefixes) {
      final prefix = '$p-';
      if (dest.startsWith(prefix) && dest.substring(prefix.length) == code) {
        return true;
      }
    }
  }

  final oblType = row['obligation_type']?.toString().trim() ?? '';
  if (oblType == code) return true;

  return false;
}

class CooperativeCashBankAccount {
  const CooperativeCashBankAccount({
    required this.id,
    required this.bankCode,
    required this.accountName,
    required this.accountNumber,
  });

  final String id;
  final String bankCode;
  final String accountName;
  final String accountNumber;

  factory CooperativeCashBankAccount.fromJson(Map<String, dynamic> m) {
    return CooperativeCashBankAccount(
      id: m['id']?.toString() ?? '',
      bankCode: m['bank']?.toString().trim() ?? '',
      accountName: m['account_name']?.toString().trim() ?? '',
      accountNumber: m['account_number']?.toString().trim() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bank': bankCode,
    'account_name': accountName,
    'account_number': accountNumber,
  };
}

class MemberObligationsRepository {
  MemberObligationsRepository(this._dioClient);

  final DioClient _dioClient;

  /// Single-obligation fetch used by the push-tap deep link. Hits
  /// `/v1/members/obligations/{id}` which returns `{obligation: {…},
  /// account: {…}}` — both halves needed by `Obligation.fromBackend`.
  /// Returns null when the id is empty or the row doesn't exist /
  /// belongs to a different member (server 404s in both cases).
  Future<Obligation?> fetchObligationById(
    String id, {
    String fallbackCurrency = 'NGN',
  }) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersObligationById(trimmed),
      );
      final data = response.data;
      final rawObligation = data is Map ? data['obligation'] : null;
      if (rawObligation is! Map) return null;
      final rawAccount = data is Map ? data['account'] : null;
      return Obligation.fromBackend(
        obligation: Map<String, dynamic>.from(rawObligation),
        account: rawAccount is Map
            ? Map<String, dynamic>.from(rawAccount)
            : null,
        fallbackCurrency: fallbackCurrency,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      // Soft-fail on network errors — caller (push handler) drops on
      // the obligations list as a safe fallback.
      return null;
    }
  }

  Future<List<Obligation>> fetchMemberObligations(UserModel user) async {
    final cooperativeId = user.cooperativeId?.trim() ?? '';
    final ledgerNumber = user.ledgerNumber?.trim() ?? '';
    if (cooperativeId.isEmpty || ledgerNumber.isEmpty) {
      return const [];
    }

    try {
      final responses = await Future.wait([
        _dioClient.get(
          ApiEndpoints.membersFinancialObligations(ledgerNumber, cooperativeId),
        ),
        _dioClient.get(ApiEndpoints.fetchInternalAccounts(cooperativeId)),
      ]);

      final obligationsData = responses[0].data;
      final accountsData = responses[1].data;

      final rawObligations = obligationsData is Map
          ? obligationsData['obligations']
          : null;
      final rawAccounts = accountsData is Map ? accountsData['accounts'] : null;
      if (rawObligations is! List) return const [];

      final accountByCode = <String, Map<String, dynamic>>{};
      if (rawAccounts is List) {
        for (final item in rawAccounts) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final code = map['account_code']?.toString().trim() ?? '';
          if (code.isNotEmpty) {
            accountByCode[code] = map;
          }
        }
      }

      final fallbackCurrency = resolveCurrencyCode(user);

      return rawObligations
          .whereType<Map>()
          .map((row) {
            final map = Map<String, dynamic>.from(row);
            final code = map['account_code']?.toString().trim() ?? '';
            return Obligation.fromBackend(
              obligation: map,
              account: accountByCode[code],
              fallbackCurrency: fallbackCurrency,
            );
          })
          .toList(growable: false);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to fetch obligations');
    }
  }

  Future<List<FineRecord>> fetchMemberFines(UserModel user) async {
    final cooperativeId = user.cooperativeId?.trim() ?? '';
    final ledgerNumber = user.ledgerNumber?.trim() ?? '';
    if (cooperativeId.isEmpty || ledgerNumber.isEmpty) return const [];
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersFines(ledgerNumber, cooperativeId),
      );
      final data = response.data;
      final raw = data is Map ? data['fines'] : null;
      if (raw is! List) return const [];
      final fallbackCurrency = resolveCurrencyCode(user);
      return Obligation.parseFines(raw, fallbackCurrency);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      return const [];
    }
  }

  Future<List<PaymentRecord>> fetchObligationPaymentHistory({
    required UserModel user,
    required Obligation obligation,
  }) async {
    final ledgerNumber = user.ledgerNumber?.trim() ?? '';
    if (ledgerNumber.isEmpty || obligation.accountCode.trim().isEmpty) {
      return const [];
    }

    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersFetchMemberTransactions(ledgerNumber),
      );
      final data = response.data;
      final raw = data is Map ? (data['data'] ?? data['transactions']) : null;
      if (raw is! List) return const [];

      final coopId = user.cooperativeId?.trim() ?? '';
      final rows =
          raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((
            row,
          ) {
            if (coopId.isNotEmpty) {
              final rCoop = row['cooperative_id']?.toString().trim() ?? '';
              if (rCoop.isNotEmpty && rCoop != coopId) return false;
            }
            // Inflows (`trx_type=1`, money entering this obligation
            // from wallet/NIP/another obligation) always count.
            //
            // Outflows (`trx_type=2`) are only legitimate when this
            // obligation actively funded ANOTHER obligation. Backend
            // (FinancialObligationController::processPayment) writes a
            // paired type=2 debit alongside the type=1 credit on every
            // payment regardless of mode — that paired debit is
            // re-anchored to the source obligation only for
            // `payment_mode == 'obligation'`. For nip_transfer / gateway
            // / wallet flows the debit row stays anchored to the target
            // and shows up here as a phantom "Used to pay another
            // obligation" entry. Drop those.
            final t = row['trx_type']?.toString().trim();
            if (t != '1' && t != '2') return false;
            if (t == '2') {
              final mode = (row['payment_mode']?.toString() ?? '')
                  .trim()
                  .toLowerCase();
              if (mode != 'obligation') return false;
            }
            return _ledgerRowMatchesObligation(row, obligation);
          }).toList()..sort((a, b) {
            final ad =
                DateTime.tryParse(a['created_at']?.toString() ?? '') ??
                DateTime(1970);
            final bd =
                DateTime.tryParse(b['created_at']?.toString() ?? '') ??
                DateTime(1970);
            return bd.compareTo(ad);
          });

      return rows
          .map((row) {
            final amountMinor = _parseInt(row['amount']);
            final date =
                DateTime.tryParse(row['created_at']?.toString() ?? '') ??
                DateTime.now();
            final mode = row['payment_mode']?.toString().trim();
            final isBf = row['brought_forward']?.toString().trim() == '1';
            final isOutflow = row['trx_type']?.toString().trim() == '2';
            final modeLower = (mode ?? '').toLowerCase();
            final String title;
            if (isOutflow) {
              // Legitimate obligation → obligation outflow (filtered above
              // to mode == 'obligation'). The backend writes the target's
              // identifier into the row's `destination` field as either
              // "obligation-{code}" or "{AccountType}-{code}"; surface it
              // in the title so the row reads "Used to pay {target}"
              // instead of an opaque "another obligation".
              final dest = (row['destination']?.toString() ?? '').trim();
              final stripped = dest.startsWith('obligation-')
                  ? dest.substring('obligation-'.length)
                  : dest;
              title = stripped.isEmpty
                  ? 'Used to pay another obligation'
                  : 'Used to pay $stripped';
            } else if (isBf || modeLower.contains('brought forward')) {
              title = 'Brought forward';
            } else {
              title = 'Payment received';
            }
            return PaymentRecord(
              title: title,
              date: date,
              amountMinor: amountMinor,
              currency: obligation.currency,
              method: (mode == null || mode.isEmpty) ? 'Wallet' : mode,
              reference: row['trx_ref_id']?.toString() ?? '',
              isOutflow: isOutflow,
            );
          })
          .toList(growable: false);
    } on DioException {
      return const [];
    }
  }

  Future<List<CooperativeCashBankAccount>>
  fetchCooperativeCashBankAccounts() async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersCooperativeCashRepositories,
      );
      final data = response.data;
      if (data is! Map || data['status'] != true) {
        return const [];
      }
      final raw = data['repositories'];
      if (raw is! List) return const [];
      final list = raw
          .whereType<Map>()
          .map(
            (e) => CooperativeCashBankAccount.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .where(
            (e) =>
                e.id.isNotEmpty &&
                e.bankCode.isNotEmpty &&
                e.accountNumber.isNotEmpty,
          )
          .toList(growable: false);
      if (list.isEmpty) {
        final msg = data['message']?.toString().trim();
        if (msg != null && msg.isNotEmpty) {
          throw Exception(msg);
        }
      }
      return list;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to load cooperative bank accounts');
    }
  }

  Future<void> verifySecurityPin(String pin) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.membersVerifySecurityPin,
        data: {'security_pin': pin},
      );
      final data = response.data;
      if (data is Map && data['status'] == true) return;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('PIN verification failed');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('PIN verification failed');
    }
  }

  /// After a successful NIP transfer to the cooperative cash repository,
  /// record obligation payment. [amountMinor] is integer minor units of
  /// the obligation's currency (kobo for NGN) — same convention the
  /// backend `pay-obligation` endpoint stores in the ledger.
  ///
  /// Hits the record-only endpoint that intentionally drops the
  /// biometric-sig requirement: the upstream `/transfer/initiate` was
  /// already biometric-signed, and this is just the bookkeeping that
  /// follows. The previous design re-prompted for biometric on the
  /// receipt screen and silently failed when the user dismissed it or
  /// biometric wasn't enrolled — wallet was debited but the obligation
  /// never incremented.
  Future<void> recordNipObligationPayment({
    required UserModel user,
    required String obligationAccountCode,
    required String transferId,
    required String cashRepositoryId,
    required int amountMinor,
    String? idempotencyKey,
  }) async {
    final cooperativeId = user.cooperativeId?.trim() ?? '';
    final ledgerNumber = user.ledgerNumber?.trim() ?? '';
    final tid = transferId.trim();
    final rid = cashRepositoryId.trim();
    if (cooperativeId.isEmpty ||
        ledgerNumber.isEmpty ||
        tid.isEmpty ||
        rid.isEmpty) {
      throw Exception('Missing payment details');
    }
    if (amountMinor <= 0) {
      throw Exception('Invalid amount');
    }
    final code = obligationAccountCode.trim();
    if (code.isEmpty) {
      throw Exception('Missing obligation');
    }

    try {
      final response = await _dioClient.post(
        ApiEndpoints.membersRecordNipObligationPayment,
        data: {
          'amount': amountMinor.toString(),
          'obligation': code,
          'ledger_number': ledgerNumber,
          'gateway': 'nip_transfer',
          'gateway_id': tid,
          'cooperative': cooperativeId,
          'cash_repository_id': rid,
        },
        idempotencyKey: idempotencyKey,
      );
      final data = response.data;
      if (response.statusCode == 200) return;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to record obligation payment');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to record obligation payment');
    }
  }

  /// Pay one obligation using the contributed balance of another. Hits the
  /// same `members/pay-obligation` endpoint as the NIP path but with
  /// `gateway: 'obligation'` — the backend atomically decrements the
  /// source obligation's `amount_paid` and credits the target.
  ///
  /// Equities are blocked client-side from being a *source*: the picker
  /// filters them out before this method is called. (The backend does
  /// not enforce that constraint today; product rule lives in the UI.)
  Future<void> payObligationFromObligation({
    required UserModel user,
    required String targetObligationAccountCode,
    required String sourceObligationAccountCode,
    required int amountMinor,
    String? idempotencyKey,
    Map<String, String>? biometricHeaders,
  }) async {
    final cooperativeId = user.cooperativeId?.trim() ?? '';
    final ledgerNumber = user.ledgerNumber?.trim() ?? '';
    final target = targetObligationAccountCode.trim();
    final source = sourceObligationAccountCode.trim();
    if (cooperativeId.isEmpty || ledgerNumber.isEmpty) {
      throw Exception('Missing payment details');
    }
    if (target.isEmpty) throw Exception('Missing target obligation');
    if (source.isEmpty) throw Exception('Missing source obligation');
    if (target == source) {
      throw Exception('Source and target obligations must differ');
    }
    if (amountMinor <= 0) {
      throw Exception('Invalid amount');
    }

    try {
      final response = await _dioClient.post(
        ApiEndpoints.membersPayObligation,
        data: {
          'amount': amountMinor.toString(),
          'obligation': target,
          'ledger_number': ledgerNumber,
          'gateway': 'obligation',
          'gateway_id': source,
          'cooperative': cooperativeId,
        },
        idempotencyKey: idempotencyKey,
        extraHeaders: biometricHeaders,
      );
      final data = response.data;
      if (response.statusCode == 200) return;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to pay obligation from obligation');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to pay obligation from obligation');
    }
  }

  Future<void> payFineFromObligation({
    required UserModel user,
    required String fineId,
    required String sourceObligationAccountCode,
    required int amountMinor,
    required String cooperativeId,
    String? idempotencyKey,
    Map<String, String>? biometricHeaders,
  }) async {
    final ledgerNumber = user.ledgerNumber?.trim() ?? '';
    final source = sourceObligationAccountCode.trim();
    if (ledgerNumber.isEmpty || cooperativeId.isEmpty || fineId.isEmpty || source.isEmpty) {
      throw Exception('Missing payment details');
    }
    if (amountMinor <= 0) throw Exception('Invalid amount');

    try {
      final response = await _dioClient.post(
        ApiEndpoints.membersPayFine,
        data: {
          'fine_id': fineId,
          'amount': amountMinor.toString(),
          'ledger_number': ledgerNumber,
          'cooperative': cooperativeId,
          'gateway': 'obligation',
          'gateway_id': source,
        },
        idempotencyKey: idempotencyKey,
        extraHeaders: biometricHeaders,
      );
      if (response.statusCode == 200) return;
      final data = response.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to process fine payment');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to process fine payment');
    }
  }

  Future<void> recordNipFinePayment({
    required UserModel user,
    required String fineId,
    required String transferId,
    required String cashRepositoryId,
    required int amountMinor,
    required String cooperativeId,
    String? idempotencyKey,
  }) async {
    final ledgerNumber = user.ledgerNumber?.trim() ?? '';
    if (ledgerNumber.isEmpty || cooperativeId.isEmpty || fineId.isEmpty ||
        transferId.isEmpty || cashRepositoryId.isEmpty) {
      throw Exception('Missing payment details');
    }
    if (amountMinor <= 0) throw Exception('Invalid amount');

    try {
      final response = await _dioClient.post(
        ApiEndpoints.membersRecordNipFinePayment,
        data: {
          'fine_id': fineId,
          'amount': amountMinor.toString(),
          'ledger_number': ledgerNumber,
          'cooperative': cooperativeId,
          'gateway': 'nip_transfer',
          'gateway_id': transferId,
          'cash_repository_id': cashRepositoryId,
        },
        idempotencyKey: idempotencyKey,
      );
      if (response.statusCode == 200) return;
      final data = response.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to record fine payment');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to record fine payment');
    }
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return 0;
    return int.tryParse(raw) ?? double.tryParse(raw)?.toInt() ?? 0;
  }
}
