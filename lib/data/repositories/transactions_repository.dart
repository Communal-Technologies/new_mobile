import 'dart:convert';

import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/mappers/transaction_history_mapper.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/transactions/models/sample_transactions.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransactionsRepository {
  TransactionsRepository(this._dioClient);

  final DioClient _dioClient;

  /// Raise a transaction issue report → Communal platform admin
  /// (transactions-svc). Returns the server message on success; throws on
  /// failure with a readable message.
  Future<String> submitTransactionIssue({
    required String category,
    required String description,
    String? transactionReference,
    String? transactionType,
    int? amountMinor,
    String? currency,
    String? contactEmail,
    String? contactPhone,
  }) async {
    try {
      final body = <String, dynamic>{
        'category': category,
        'description': description,
        if (transactionReference != null && transactionReference.trim().isNotEmpty)
          'transaction_reference': transactionReference.trim(),
        if (transactionType != null && transactionType.trim().isNotEmpty)
          'transaction_type': transactionType.trim(),
        if (amountMinor != null) 'amount_minor': amountMinor,
        if (currency != null && currency.trim().isNotEmpty)
          'currency': currency.trim(),
        if (contactEmail != null && contactEmail.trim().isNotEmpty)
          'contact_email': contactEmail.trim(),
        if (contactPhone != null && contactPhone.trim().isNotEmpty)
          'contact_phone': contactPhone.trim(),
      };
      final response = await _dioClient.post(
        ApiEndpoints.transactionIssues,
        data: body,
      );
      final data = response.data;
      if (data is Map && data['status'] == true) {
        final d = data['data'];
        final msg = d is Map ? d['message']?.toString() : null;
        return (msg == null || msg.isEmpty)
            ? 'Your report has been submitted.'
            : msg;
      }
      throw Exception(
        (data is Map ? data['message']?.toString() : null) ??
            'Could not submit your report.',
      );
    } on DioException catch (e) {
      final d = e.response?.data;
      final msg = d is Map ? d['message']?.toString() : null;
      throw Exception(msg ?? 'Could not submit your report. Please try again.');
    }
  }

  // ── Local history cache (stale-while-revalidate) ──────────────────────────
  // We cache the raw backend rows per scope so the history screen can render
  // instantly from disk and refresh in the background, instead of showing a
  // loader on every open.
  SharedPreferences? get _prefs =>
      getIt.isRegistered<SharedPreferences>() ? getIt<SharedPreferences>() : null;

  String _communalCacheKey(String userId) => 'txn_cache_communal_$userId';
  String _ledgerCacheKey(String ln) => 'txn_cache_ledger_$ln';

  void _writeRawCache(String key, List<Map<String, dynamic>> rows) {
    try {
      _prefs?.setString(key, jsonEncode(rows));
    } catch (_) {/* cache is best-effort */}
  }

  List<Map<String, dynamic>> _readRawCache(String key) {
    try {
      final s = _prefs?.getString(key);
      if (s == null || s.isEmpty) return const [];
      final decoded = jsonDecode(s);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

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
      final rows = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
      _writeRawCache(_communalCacheKey(uid), rows);
      return rows;
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
      final rows = raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
      _writeRawCache(_ledgerCacheKey(ln), rows);
      return rows;
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

  /// Cached counterpart of [fetchPersonalHistoryMerged]: maps + merges the
  /// last-cached raw rows synchronously for an instant render. Empty when there
  /// is no cache yet.
  List<TransactionListItem> cachedPersonalHistoryMerged(UserModel user) {
    final communalRaw = _readRawCache(_communalCacheKey(user.id.trim()));
    final sym = currencySymbolForUser(user);
    final communal = communalRaw
        .map((e) => mapCommunalTransactionToListItem(e, currencySymbol: sym))
        .toList(growable: false);
    final ln = user.ledgerNumber?.trim() ?? '';
    if (!user.hasCooperativeMembership || ln.isEmpty) return communal;
    final ledgerRaw = _readRawCache(_ledgerCacheKey(ln));
    final obligationRows =
        ledgerRaw.where(ledgerRowShouldMirrorOnPersonalTab).toList();
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

  /// Cached counterpart of [fetchLedgerHistoryOnly].
  List<TransactionListItem> cachedLedgerHistoryOnly(UserModel user) {
    final ln = user.ledgerNumber?.trim() ?? '';
    if (ln.isEmpty) return const [];
    final raw = _readRawCache(_ledgerCacheKey(ln));
    final sym = currencySymbolForUser(user);
    return raw
        .map(
          (e) => mapLedgerRowToListItem(
            e,
            cooperativeLabel: user.cooperativeDisplayName,
            currencySymbol: sym,
          ),
        )
        .toList(growable: false);
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
