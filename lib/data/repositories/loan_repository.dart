import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/guarantor_request.dart';
import 'package:communal_mobile/data/models/loan_application.dart';
import 'package:communal_mobile/data/models/loan_eligibility.dart';
import 'package:communal_mobile/data/models/loan_guarantor.dart';
import 'package:communal_mobile/data/models/loan_installment.dart';
import 'package:communal_mobile/data/models/loan_scheme.dart';
import 'package:communal_mobile/data/models/member_search_result.dart';
import 'package:communal_mobile/data/models/user_model.dart';

/// Member-side loan endpoints. Mirrors `MemberObligationsRepository` —
/// thin wrapper over [DioClient] that returns typed models. All money
/// values cross the wire as integer minor units (kobo for NGN); we send
/// the major-unit form on `apply` because the backend's `store` method
/// multiplies by 100 itself.
class LoanRepository {
  LoanRepository(this._dio);

  final DioClient _dio;

  Future<List<LoanScheme>> fetchSchemes(String cooperativeId) async {
    final id = cooperativeId.trim();
    if (id.isEmpty) return const [];
    try {
      final response = await _dio.get(ApiEndpoints.membersFetchLoanSchemes(id));
      final data = _unwrap(response.data);
      final raw = data is Map ? data['schemes'] : null;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => LoanScheme.fromBackend(Map<String, dynamic>.from(e)))
          .where((s) => s.loanCode.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to fetch loan schemes');
    }
  }

  /// Single-loan fetch used when a push notification (or any other
  /// surface that only knows the loan id) needs to deep-link into
  /// the loan-detail screen. Hits the shared auth endpoint
  /// `/v1/fetch-loan-details/{id}` which already returns a
  /// `{loanDetail: {…}}` shape with `loan_title` mixed in.
  /// Returns null when the id is empty / not found.
  Future<LoanApplication?> fetchLoanById(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;
    try {
      final response = await _dio.get(
        ApiEndpoints.fetchLoanDetailsById(trimmed),
      );
      final data = _unwrap(response.data);
      final raw = data is Map ? data['loanDetail'] : null;
      if (raw is! Map) return null;
      return LoanApplication.fromBackend(Map<String, dynamic>.from(raw));
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to fetch loan details');
    }
  }

  Future<List<LoanApplication>> fetchMyLoans(UserModel user) async {
    final ledger = user.ledgerNumber?.trim() ?? '';
    if (ledger.isEmpty) return const [];
    try {
      final response = await _dio.get(
        ApiEndpoints.membersFetchUserLoans(ledger),
      );
      final data = _unwrap(response.data);
      final raw = data is Map ? data['loans'] : null;
      if (raw is! List) return const [];
      final fallback = resolveCurrencyCode(user);
      return raw
          .whereType<Map>()
          .map(
            (e) => LoanApplication.fromBackend(
              Map<String, dynamic>.from(e),
              fallbackCurrency: fallback,
            ),
          )
          .toList(growable: false);
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to fetch loans');
    }
  }

  /// Cooperative-driven eligibility envelope for the apply screen:
  /// min/max bounds (kobo) and the configured interest treatment.
  Future<LoanEligibility?> fetchEligibility(String cooperativeId) async {
    final coop = cooperativeId.trim();
    if (coop.isEmpty) return null;
    try {
      final response = await _dio.get(
        ApiEndpoints.membersLoanEligibility(coop),
      );
      final data = _unwrap(response.data);
      if (data is Map) {
        return LoanEligibility.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to fetch loan eligibility');
    }
  }

  /// Per-loan installment schedule. Returns the materialised
  /// `loan_installments` rows for [loanId], or an empty list when the
  /// loan has no schedule (legacy approval / brought-forward import).
  Future<List<LoanInstallment>> fetchInstallments(String loanId) async {
    final id = loanId.trim();
    if (id.isEmpty) return const [];
    try {
      final response = await _dio.get(
        ApiEndpoints.membersFetchLoanInstallments(id),
      );
      final data = _unwrap(response.data);
      final raw = data is Map ? data['installments'] : null;
      final fallback = (data is Map ? data['currency']?.toString() : null) ?? 'NGN';
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => LoanInstallment.fromJson(
                Map<String, dynamic>.from(e),
                fallbackCurrency: fallback,
              ))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to fetch installment schedule');
    }
  }

  /// Full regrant chain (ancestors + descendants) anchored to the
  /// loan's `regrant_chain_root_id`. Returned in chronological order.
  Future<List<LoanApplication>> fetchRegrantChain({
    required String loanId,
    String? fallbackCurrency,
  }) async {
    final id = loanId.trim();
    if (id.isEmpty) return const [];
    try {
      final response = await _dio.get(
        ApiEndpoints.membersFetchLoanRegrantChain(id),
      );
      final data = _unwrap(response.data);
      final raw = data is Map ? data['chain'] : null;
      final cur = (data is Map ? data['currency']?.toString() : null)
          ?? fallbackCurrency
          ?? 'NGN';
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => LoanApplication.fromBackend(
                Map<String, dynamic>.from(e),
                fallbackCurrency: cur,
              ))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to fetch regrant chain');
    }
  }

  /// Outstanding kobo balance across all approved loans for the member.
  Future<int> fetchLoanBalanceMinor(String ledgerNumber) async {
    final ledger = ledgerNumber.trim();
    if (ledger.isEmpty) return 0;
    try {
      final response = await _dio.get(
        ApiEndpoints.membersFetchLoanBalance(ledger),
      );
      final data = _unwrap(response.data);
      final raw = data is Map ? data['balance'] : null;
      return _asInt(raw);
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to fetch loan balance');
    }
  }

  /// Loan repayment ledger rows for a given loan. The cooperative's
  /// admin-side processor writes ledger rows with
  /// `destination='Loan-{reference_id}_{loan_id}'` (see
  /// `MembersController::createLedgerEntries`); we filter the member's
  /// transaction list by that prefix to surface a per-loan history.
  ///
  /// Brought-forward uploads also write to the same destination prefix
  /// (`Loan-{reference}` with `payment_mode='Brought Forward Upload'`
  /// or `source='Brought Forward'`) — those rows are *loan creations*,
  /// not repayments, and were leaking into the history with the loan
  /// principal (or sometimes 0) as the displayed amount. Same for
  /// "Brought Forward Correction" reversals. Drop both, plus any row
  /// with amount ≤ 0, before returning.
  Future<List<Map<String, dynamic>>> fetchLoanRepayments({
    required String ledgerNumber,
    required String referenceId,
  }) async {
    final ledger = ledgerNumber.trim();
    final ref = referenceId.trim();
    if (ledger.isEmpty || ref.isEmpty) return const [];
    try {
      final response = await _dio.get(
        ApiEndpoints.membersFetchMemberTransactions(ledger),
      );
      final data = response.data;
      final raw = data is Map ? (data['data'] ?? data['transactions']) : null;
      if (raw is! List) return const [];
      final prefix = 'Loan-$ref';
      bool isBroughtForwardArtifact(Map<String, dynamic> row) {
        final mode = row['payment_mode']?.toString().trim().toLowerCase() ?? '';
        final source = row['source']?.toString().trim().toLowerCase() ?? '';
        if (mode.contains('brought forward')) return true;
        if (source == 'brought forward') return true;
        if (source == 'brought forward correction') return true;
        return false;
      }

      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((row) {
            final dest = row['destination']?.toString().trim() ?? '';
            if (!dest.startsWith(prefix)) return false;
            if (isBroughtForwardArtifact(row)) return false;
            final amt = num.tryParse(row['amount']?.toString() ?? '0') ?? 0;
            if (amt <= 0) return false;
            return true;
          })
          .toList()
        ..sort((a, b) {
          final ad =
              DateTime.tryParse(a['created_at']?.toString() ?? '') ??
              DateTime(1970);
          final bd =
              DateTime.tryParse(b['created_at']?.toString() ?? '') ??
              DateTime(1970);
          return bd.compareTo(ad);
        });
    } on DioException {
      return const [];
    }
  }

  Future<List<MemberSearchResult>> searchGuarantors({
    required String cooperativeId,
    required String query,
    int limit = 20,
  }) async {
    final coop = cooperativeId.trim();
    final q = query.trim();
    if (coop.isEmpty || q.isEmpty) return const [];
    try {
      final response = await _dio.get(
        ApiEndpoints.membersLoanSearchGuarantors,
        queryParameters: {'cooperative': coop, 'q': q, 'limit': limit},
      );
      final data = _unwrap(response.data);
      final raw = data is Map ? data['members'] : null;
      if (raw is! List) return const [];
      return raw
          .whereType<Map>()
          .map((e) => MemberSearchResult.fromJson(Map<String, dynamic>.from(e)))
          .where((m) => m.ledgerNumber.isNotEmpty)
          .toList(growable: false);
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to search members');
    }
  }

  Future<List<GuarantorRequest>> fetchGuarantorRequests(UserModel user) async {
    final ledger = user.ledgerNumber?.trim() ?? '';
    if (ledger.isEmpty) return const [];
    try {
      final response = await _dio.get(
        ApiEndpoints.membersFetchGuarantorRequests(ledger),
      );
      final data = _unwrap(response.data);
      // loans-svc returns guarantor requests under `approvals`; the legacy
      // monolith used `requests`. Accept either.
      final raw = data is Map ? (data['approvals'] ?? data['requests']) : null;
      if (raw is! List) return const [];
      final fallback = resolveCurrencyCode(user);
      return raw
          .whereType<Map>()
          .map(
            (e) => GuarantorRequest.fromBackend(
              Map<String, dynamic>.from(e),
              fallbackCurrency: fallback,
            ),
          )
          .toList(growable: false);
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to fetch guarantor requests');
    }
  }

  /// Per-loan guarantor list (name + status + expiry + last-reminded).
  /// Drives the per-guarantor card on the applicant's loan-detail
  /// screen so they can see who has approved / declined / is still
  /// pending and act on rows individually (remind / replace).
  Future<LoanGuarantorList> fetchGuarantorsForLoan(String loanRef) async {
    try {
      final response = await _dio.get(
        ApiEndpoints.membersGuarantorsForLoan(loanRef),
      );
      if (response.statusCode == 200) {
        final data = _unwrap(response.data);
        if (data is Map) {
          return LoanGuarantorList.fromJson(Map<String, dynamic>.from(data));
        }
      }
      throw Exception('Unable to fetch guarantors');
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to fetch guarantors');
    }
  }

  /// Re-fire the invitation SMS / push for a still-pending guarantor
  /// invitation. Backend rate-limits to one reminder per 24h and
  /// rejects the call if the row has already expired (the only post-
  /// expiry path is replace).
  Future<void> remindGuarantor(String approvalId) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.membersGuarantorRemind(approvalId),
      );
      if (response.statusCode == 200) return;
      final data = response.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to send reminder');
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to send reminder');
    }
  }

  /// Swap a still-unresolved (or expired) guarantor for a new one.
  /// Backend closes the old row (`status='2'`), creates a fresh
  /// pending row for [newGuarantorLedger] with a 7-day expiry, and
  /// fires the standard invitation push / SMS to the new guarantor.
  Future<void> replaceGuarantor({
    required String oldApprovalId,
    required String newGuarantorLedger,
  }) async {
    try {
      final response = await _dio.post(
        ApiEndpoints.membersGuarantorReplace,
        data: {
          'old_approval_id': oldApprovalId,
          'new_guarantor_ledger': newGuarantorLedger,
        },
      );
      if (response.statusCode == 200) return;
      final data = response.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to replace guarantor');
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to replace guarantor');
    }
  }

  /// Accept (`action='1'`) or decline (any other value) a guarantor
  /// request. Backend writes the response back to
  /// `guarantors_loan_approvals.status` and, on accept, appends the
  /// guarantor's ledger to the loan's csv `guarantors` column.
  Future<void> respondToGuarantorRequest({
    required String requestId,
    required String guarantorLedger,
    required bool accept,
  }) async {
    try {
      final response = await _dio.put(
        ApiEndpoints.membersUpdateGuarantorApproval,
        data: {
          'id': requestId,
          'guarantor': guarantorLedger,
          'action': accept ? '1' : '0',
        },
      );
      if (response.statusCode == 200) return;
      final data = response.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to update guarantor request');
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to update guarantor request');
    }
  }

  /// Submit a new loan application. [amountMajor] is in main currency
  /// units (e.g. naira) — the backend multiplies by 100 internally.
  /// [interestType] is `'1'` for deduct-on-disbursal or `'2'` for
  /// add-to-principal. [loanSecurity] is `'guarantors'` (default) or
  /// `'token'` (cooperative-issued collateral token).
  ///
  /// Returns the backend response payload so the caller can pull the
  /// reference id / message for the success screen.
  Future<Map<String, dynamic>> applyForLoan({
    required UserModel user,
    required LoanScheme scheme,
    required num amountMajor,
    required String interestType,
    required String reasonForLoan,
    int? pickedDurationMonths,
    List<String> guarantorLedgers = const [],
    String? collateralToken,
  }) async {
    final cooperativeId = user.cooperativeId?.trim() ?? '';
    final ledger = user.ledgerNumber?.trim() ?? '';
    if (cooperativeId.isEmpty || ledger.isEmpty) {
      throw Exception('Missing member context');
    }
    final loanSecurity =
        (collateralToken != null && collateralToken.trim().isNotEmpty)
        ? 'token'
        : 'guarantors';
    if (loanSecurity == 'guarantors' &&
        scheme.numberOfGuarantors > 0 &&
        guarantorLedgers.length != scheme.numberOfGuarantors) {
      throw Exception(
        'This loan needs ${scheme.numberOfGuarantors} guarantor'
        '${scheme.numberOfGuarantors == 1 ? '' : 's'}',
      );
    }

    final payload = <String, dynamic>{
      'ledger_number': ledger,
      'cooperative_id': cooperativeId,
      // The backend approve flow reads `loan_data.duration` first
      // (member-picked), falling back to scheme.max_duration_months.
      // Passing `pickedDurationMonths` here is what plumbs the
      // member's slider choice through to the materialised
      // amortisation schedule.
      'loan_data': jsonEncode(scheme.toBackendJson(
        pickedDurationMonths: pickedDurationMonths,
      )),
      'amount': amountMajor,
      'interest_type': interestType,
      'reason_for_loan': reasonForLoan,
      'loan_security': loanSecurity,
    };
    if (loanSecurity == 'guarantors' && guarantorLedgers.isNotEmpty) {
      payload['guarantors'] = guarantorLedgers.join(',');
    }
    if (loanSecurity == 'token' && collateralToken != null) {
      payload['collateral_token'] = collateralToken;
    }

    try {
      final response = await _dio.post(
        ApiEndpoints.membersLoanApplication,
        data: payload,
      );
      // loans-svc returns 201 Created for a new application.
      if (response.statusCode == 200 || response.statusCode == 201) {
        final inner = _unwrap(response.data);
        return inner is Map ? Map<String, dynamic>.from(inner) : const {};
      }
      final data = response.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to submit loan application');
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to submit loan application');
    }
  }

  /// Pay down an approved loan from a non-equity obligation balance.
  /// Hits the biometric-gated `/members/loan/pay` endpoint with
  /// `gateway='obligation'`. Backend rejects equity sources, so the
  /// mobile picker is the first line of defense and this call is the
  /// second.
  Future<void> payLoanFromObligation({
    required UserModel user,
    required String loanId,
    required String sourceObligationAccountCode,
    required int amountMinor,
    String? idempotencyKey,
    Map<String, String>? biometricHeaders,
  }) async {
    final cooperativeId = user.cooperativeId?.trim() ?? '';
    final ledgerNumber = user.ledgerNumber?.trim() ?? '';
    final source = sourceObligationAccountCode.trim();
    final id = loanId.trim();
    if (cooperativeId.isEmpty || ledgerNumber.isEmpty) {
      throw Exception('Missing payment details');
    }
    if (id.isEmpty) throw Exception('Missing loan');
    if (source.isEmpty) throw Exception('Missing source obligation');
    if (amountMinor <= 0) throw Exception('Invalid amount');

    try {
      final response = await _dio.post(
        ApiEndpoints.membersPayLoan,
        data: {
          'amount': amountMinor.toString(),
          'loan_id': id,
          'ledger_number': ledgerNumber,
          'gateway': 'obligation',
          'gateway_id': source,
          'cooperative': cooperativeId,
        },
        idempotencyKey: idempotencyKey,
        extraHeaders: biometricHeaders,
      );
      if (response.statusCode == 200) return;
      final data = response.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to record loan repayment');
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to record loan repayment');
    }
  }

  /// After a successful NIP transfer to the cooperative cash repository,
  /// record the loan repayment. No biometric headers — the upstream
  /// `/transfer/initiate` already required a signature, and the
  /// backend independently re-verifies the transfer belongs to this
  /// member, completed at Anchor, lands in the right cooperative cash
  /// repo, and matches the amount.
  Future<void> recordNipLoanPayment({
    required UserModel user,
    required String loanId,
    required String transferId,
    required String cashRepositoryId,
    required int amountMinor,
    String? idempotencyKey,
  }) async {
    final cooperativeId = user.cooperativeId?.trim() ?? '';
    final ledgerNumber = user.ledgerNumber?.trim() ?? '';
    final id = loanId.trim();
    final tid = transferId.trim();
    final rid = cashRepositoryId.trim();
    if (cooperativeId.isEmpty ||
        ledgerNumber.isEmpty ||
        id.isEmpty ||
        tid.isEmpty ||
        rid.isEmpty) {
      throw Exception('Missing payment details');
    }
    if (amountMinor <= 0) throw Exception('Invalid amount');

    try {
      final response = await _dio.post(
        ApiEndpoints.membersRecordNipLoanPayment,
        data: {
          'amount': amountMinor.toString(),
          'loan_id': id,
          'ledger_number': ledgerNumber,
          'gateway': 'nip_transfer',
          'gateway_id': tid,
          'cooperative': cooperativeId,
          'cash_repository_id': rid,
        },
        idempotencyKey: idempotencyKey,
      );
      if (response.statusCode == 200) return;
      final data = response.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to record loan repayment');
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to record loan repayment');
    }
  }

  /// Cancel a pending loan application by reference id. Backend route
  /// expects the reference in the request body.
  Future<void> cancelApplication(String referenceId) async {
    final ref = referenceId.trim();
    if (ref.isEmpty) throw Exception('Missing loan reference');
    try {
      // loans-svc: PUT /api/loans/v2/{id}/cancel (id in path, no body).
      final response = await _dio.put(
        ApiEndpoints.membersLoanCancelRequest(ref),
      );
      if (response.statusCode == 200) return;
      final data = response.data;
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to cancel application');
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to cancel application');
    }
  }

  /// loans-svc wraps every success response as `{status:"success", data:{…}}`.
  /// Return the inner payload so the existing key-based parsing works unchanged.
  static dynamic _unwrap(dynamic body) {
    if (body is Map &&
        body['data'] != null &&
        (body['status'] == 'success' || body['status'] == true)) {
      return body['data'];
    }
    return body;
  }

  Exception _wrap(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return Exception(data['message'].toString());
    }
    return Exception(fallback);
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString().trim() ?? '') ??
        double.tryParse(v?.toString().trim() ?? '')?.toInt() ??
        0;
  }
}
