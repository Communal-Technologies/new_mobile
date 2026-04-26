import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/screens/obligations/data/sample_obligations.dart';
import 'package:dio/dio.dart';

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

      final rows = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where((row) {
        final code = row['obligation_type']?.toString().trim() ?? '';
        return code == obligation.accountCode;
      }).toList()
        ..sort((a, b) {
          final ad = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime(1970);
          final bd = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime(1970);
          return bd.compareTo(ad);
        });

      return rows.map((row) {
        final amountKobo = _parseDouble(row['amount']);
        final amountMajor = amountKobo / 100;
        final date = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now();
        final type = row['trx_type']?.toString() ?? '';
        final mode = row['payment_mode']?.toString().trim();
        return PaymentRecord(
          title: type == '1' ? 'Payment Credit' : 'Payment Debit',
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

  Future<void> payObligation({
    required UserModel user,
    required Obligation obligation,
    required double amount,
  }) async {
    final cooperativeId = user.cooperativeId?.trim() ?? '';
    final ledgerNumber = user.ledgerNumber?.trim() ?? '';
    final walletId = user.walletAccountNumber?.trim() ?? '';
    if (cooperativeId.isEmpty || ledgerNumber.isEmpty || walletId.isEmpty) {
      throw Exception('Missing cooperative, ledger, or wallet information');
    }

    try {
      final response = await _dioClient.post(
        '/members/pay-obligation',
        data: {
          'amount': amount.toStringAsFixed(2),
          'obligation': obligation.accountCode,
          'ledger_number': ledgerNumber,
          'gateway': 'e-wallet',
          'gateway_id': walletId,
          'cooperative': cooperativeId,
        },
      );
      final data = response.data;
      if (response.statusCode == 200) return;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Payment failed');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to complete obligation payment');
    }
  }

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
