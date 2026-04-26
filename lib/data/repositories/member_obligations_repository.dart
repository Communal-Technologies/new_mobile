import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/screens/obligations/data/sample_obligations.dart';
import 'package:dio/dio.dart';

/// Backend stores [Ledger.destination] as `{AccountType}-{account_code}` (e.g. `Equity-IA…`)
/// and [obligation_type] as `{AccountType}-Obligation`, not the raw account code.
bool _ledgerRowMatchesObligation(Map<String, dynamic> row, Obligation obligation) {
  final code = obligation.accountCode.trim();
  if (code.isEmpty) return false;

  final dest = row['destination']?.toString().trim() ?? '';
  if (dest.isNotEmpty) {
    const prefixes = ['Equity', 'Patronage', 'Custom', 'Obligation'];
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

  Future<List<Obligation>> fetchMemberObligations(UserModel user) async {
    final cooperativeId = user.cooperativeId?.trim() ?? '';
    final ledgerNumber = user.ledgerNumber?.trim() ?? '';
    if (cooperativeId.isEmpty || ledgerNumber.isEmpty) {
      return const [];
    }

    try {
      final responses = await Future.wait([
        _dioClient.get('/members/financial-obligations/$ledgerNumber/$cooperativeId'),
        _dioClient.get('/fetch-internal-accounts/$cooperativeId'),
      ]);

      final obligationsData = responses[0].data;
      final accountsData = responses[1].data;

      final rawObligations = obligationsData is Map ? obligationsData['obligations'] : null;
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

      return rawObligations
          .whereType<Map>()
          .map((row) {
            final map = Map<String, dynamic>.from(row);
            final code = map['account_code']?.toString().trim() ?? '';
            return Obligation.fromBackend(
              obligation: map,
              account: accountByCode[code],
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

  Future<List<PaymentRecord>> fetchObligationPaymentHistory({
    required UserModel user,
    required Obligation obligation,
  }) async {
    final ledgerNumber = user.ledgerNumber?.trim() ?? '';
    if (ledgerNumber.isEmpty || obligation.accountCode.trim().isEmpty) {
      return const [];
    }

    try {
      final response = await _dioClient.get('/members/fetch-member-transactions/$ledgerNumber');
      final data = response.data;
      final raw = data is Map ? (data['data'] ?? data['transactions']) : null;
      if (raw is! List) return const [];

      final coopId = user.cooperativeId?.trim() ?? '';
      final rows = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((row) {
            if (coopId.isNotEmpty) {
              final rCoop = row['cooperative_id']?.toString().trim() ?? '';
              if (rCoop.isNotEmpty && rCoop != coopId) return false;
            }
            if (row['trx_type']?.toString().trim() != '1') {
              return false;
            }
            return _ledgerRowMatchesObligation(row, obligation);
          })
          .toList()
        ..sort((a, b) {
          final ad = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
          final bd = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
          return bd.compareTo(ad);
        });

      return rows.map((row) {
        final amountKobo = _parseDouble(row['amount']);
        final amountMajor = amountKobo / 100;
        final date = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now();
        final mode = row['payment_mode']?.toString().trim();
        final isBf = row['brought_forward']?.toString().trim() == '1';
        final modeLower = (mode ?? '').toLowerCase();
        final title = (isBf || modeLower.contains('brought forward'))
            ? 'Brought forward'
            : 'Payment received';
        return PaymentRecord(
          title: title,
          date: date,
          amount: amountMajor,
          method: (mode == null || mode.isEmpty) ? 'Wallet' : mode,
          reference: row['trx_ref_id']?.toString() ?? '',
        );
      }).toList(growable: false);
    } on DioException {
      return const [];
    }
  }

  Future<List<CooperativeCashBankAccount>> fetchCooperativeCashBankAccounts() async {
    try {
      final response = await _dioClient.get('/members/cooperative-cash-repositories');
      final data = response.data;
      if (data is! Map || data['status'] != true) {
        return const [];
      }
      final raw = data['repositories'];
      if (raw is! List) return const [];
      final list = raw
          .whereType<Map>()
          .map((e) => CooperativeCashBankAccount.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.id.isNotEmpty && e.bankCode.isNotEmpty && e.accountNumber.isNotEmpty)
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
        '/members/verify-security-pin',
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

  /// After a successful NIP transfer to the cooperative cash repository, record obligation payment.
  Future<void> recordNipObligationPayment({
    required UserModel user,
    required String obligationAccountCode,
    required String transferId,
    required String cashRepositoryId,
    required double amountNaira,
  }) async {
    final cooperativeId = user.cooperativeId?.trim() ?? '';
    final ledgerNumber = user.ledgerNumber?.trim() ?? '';
    final tid = transferId.trim();
    final rid = cashRepositoryId.trim();
    if (cooperativeId.isEmpty || ledgerNumber.isEmpty || tid.isEmpty || rid.isEmpty) {
      throw Exception('Missing payment details');
    }
    final amountKobo = (amountNaira * 100).round();
    if (amountKobo <= 0) {
      throw Exception('Invalid amount');
    }
    final code = obligationAccountCode.trim();
    if (code.isEmpty) {
      throw Exception('Missing obligation');
    }

    try {
      final response = await _dioClient.post(
        '/members/pay-obligation',
        data: {
          'amount': amountKobo.toString(),
          'obligation': code,
          'ledger_number': ledgerNumber,
          'gateway': 'nip_transfer',
          'gateway_id': tid,
          'cooperative': cooperativeId,
          'cash_repository_id': rid,
        },
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

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
