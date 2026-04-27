import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/mappers/transaction_history_mapper.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/screens/transactions/models/sample_transactions.dart';
import 'package:dio/dio.dart';

class TransactionsRepository {
  TransactionsRepository(this._dioClient);

  final DioClient _dioClient;

  Future<List<Map<String, dynamic>>> fetchCommunalTransactionsRaw(
    String userId, {
    int page = 1,
    int perPage = 50,
  }) async {
    final uid = userId.trim();
    if (uid.isEmpty) return const [];
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersFetchTransactions(uid),
        queryParameters: {
          'page': page,
          'per_page': perPage,
        },
      );
      final data = response.data;
      if (data is! Map || data['status'] != true) {
        return const [];
      }
      final raw = data['transactions'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } on DioException {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchLedgerTransactionsRaw(
    String ledgerNumber,
  ) async {
    final ln = ledgerNumber.trim();
    if (ln.isEmpty) return const [];
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersFetchMemberTransactions(ln),
      );
      final data = response.data;
      if (data is! Map) return const [];
      if (data['status'] == false) return const [];
      final raw = data['data'] ?? data['transactions'];
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } on DioException {
      return const [];
    }
  }

  Future<List<TransactionListItem>> fetchCommunalListItems(
    UserModel user, {
    int page = 1,
    int perPage = 50,
  }) async {
    final rows = await fetchCommunalTransactionsRaw(
      user.id,
      page: page,
      perPage: perPage,
    );
    final sym = currencySymbolForUser(user);
    return rows
        .map(
          (e) => mapCommunalTransactionToListItem(e, currencySymbol: sym),
        )
        .toList(growable: false);
  }

  Future<List<TransactionListItem>> fetchLedgerListItems(
    UserModel user,
    String ledgerNumber,
    String cooperativeLabel,
  ) async {
    final rows = await fetchLedgerTransactionsRaw(ledgerNumber);
    final sym = currencySymbolForUser(user);
    return rows
        .map(
          (e) => mapLedgerRowToListItem(
            e,
            cooperativeLabel: cooperativeLabel,
            currencySymbol: sym,
          ),
        )
        .toList(growable: false);
  }

  /// Communal wallet history plus cooperative obligation ledger lines (deduped by reference).
  Future<List<TransactionListItem>> fetchPersonalHistoryMerged(UserModel user) async {
    final communal = await fetchCommunalListItems(user, perPage: 80);
    if (!user.hasCooperativeMembership ||
        (user.ledgerNumber == null || user.ledgerNumber!.trim().isEmpty)) {
      return communal;
    }
    final ledgerRaw = await fetchLedgerTransactionsRaw(user.ledgerNumber!.trim());
    final obligationRows = ledgerRaw.where(ledgerRowShouldMirrorOnPersonalTab).toList();
    final sym = currencySymbolForUser(user);
    final ledgerItems = obligationRows
        .map(
          (e) => mapLedgerRowToListItem(
            e,
            cooperativeLabel: user.cooperativeDisplayName,
            currencySymbol: sym,
          ),
        )
        .toList(growable: false);
    return mergePersonalWithObligationLedgerRows(
      communal: communal,
      ledgerCandidates: ledgerItems,
    );
  }

  Future<List<TransactionListItem>> fetchLedgerHistoryOnly(UserModel user) async {
    final ln = user.ledgerNumber?.trim() ?? '';
    if (ln.isEmpty) return const [];
    return fetchLedgerListItems(user, ln, user.cooperativeDisplayName);
  }

  Future<Map<String, dynamic>> exportStatement({
    required String scope,
    required DateTime startInclusive,
    required DateTime endInclusive,
    required String format,
    required String delivery,
    String? email,
    String? ledgerNumber,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.membersTransactionStatementExport,
        data: {
          'scope': scope,
          'start_date': startInclusive.toIso8601String(),
          'end_date': endInclusive.toIso8601String(),
          'format': format,
          'delivery': delivery,
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (ledgerNumber != null && ledgerNumber.trim().isNotEmpty)
            'ledger_number': ledgerNumber.trim(),
        },
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data;
      }
      throw Exception('Invalid export response');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to export statement');
    }
  }
}
