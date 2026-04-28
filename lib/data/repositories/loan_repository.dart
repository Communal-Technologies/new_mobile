import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:communal_mobile/core/utils/app_currency.dart';
import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/guarantor_request.dart';
import 'package:communal_mobile/data/models/loan_application.dart';
import 'package:communal_mobile/data/models/loan_eligibility.dart';
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
      final response =
          await _dio.get(ApiEndpoints.membersFetchLoanSchemes(id));
      final data = response.data;
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

  Future<List<LoanApplication>> fetchMyLoans(UserModel user) async {
    final ledger = user.ledgerNumber?.trim() ?? '';
    if (ledger.isEmpty) return const [];
    try {
      final response =
          await _dio.get(ApiEndpoints.membersFetchUserLoans(ledger));
      final data = response.data;
      final raw = data is Map ? data['loans'] : null;
      if (raw is! List) return const [];
      final fallback = resolveCurrencyCode(user);
      return raw
          .whereType<Map>()
          .map((e) => LoanApplication.fromBackend(
                Map<String, dynamic>.from(e),
                fallbackCurrency: fallback,
              ))
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
      final response =
          await _dio.get(ApiEndpoints.membersLoanEligibility(coop));
      final data = response.data;
      if (data is Map) {
        return LoanEligibility.fromJson(Map<String, dynamic>.from(data));
      }
      return null;
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to fetch loan eligibility');
    }
  }

  /// Outstanding kobo balance across all approved loans for the member.
  Future<int> fetchLoanBalanceMinor(String ledgerNumber) async {
    final ledger = ledgerNumber.trim();
    if (ledger.isEmpty) return 0;
    try {
      final response =
          await _dio.get(ApiEndpoints.membersFetchLoanBalance(ledger));
      final data = response.data;
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
  Future<List<Map<String, dynamic>>> fetchLoanRepayments({
    required String ledgerNumber,
    required String referenceId,
  }) async {
    final ledger = ledgerNumber.trim();
    final ref = referenceId.trim();
    if (ledger.isEmpty || ref.isEmpty) return const [];
    try {
      final response = await _dio.get(
          ApiEndpoints.membersFetchMemberTransactions(ledger));
      final data = response.data;
      final raw = data is Map ? (data['data'] ?? data['transactions']) : null;
      if (raw is! List) return const [];
      final prefix = 'Loan-$ref';
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .where((row) {
            final dest = row['destination']?.toString().trim() ?? '';
            return dest.startsWith(prefix);
          })
          .toList()
        ..sort((a, b) {
          final ad = DateTime.tryParse(a['created_at']?.toString() ?? '') ??
              DateTime(1970);
          final bd = DateTime.tryParse(b['created_at']?.toString() ?? '') ??
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
        queryParameters: {
          'cooperative_id': coop,
          'q': q,
          'limit': limit,
        },
      );
      final data = response.data;
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
      final response =
          await _dio.get(ApiEndpoints.membersFetchGuarantorRequests(ledger));
      final data = response.data;
      final raw = data is Map ? data['requests'] : null;
      if (raw is! List) return const [];
      final fallback = resolveCurrencyCode(user);
      return raw
          .whereType<Map>()
          .map((e) => GuarantorRequest.fromBackend(
                Map<String, dynamic>.from(e),
                fallbackCurrency: fallback,
              ))
          .toList(growable: false);
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to fetch guarantor requests');
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
    required String employmentStatus,
    required String reasonForLoan,
    List<String> guarantorLedgers = const [],
    String? collateralToken,
    String? company,
    String? department,
    num? monthlySalary,
    num? outstandingLoan,
    num? otherMonthlyRepayment,
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
      'loan_data': jsonEncode(scheme.toBackendJson()),
      'amount': amountMajor,
      'interest_type': interestType,
      'employment_status': employmentStatus,
      'reason_for_loan': reasonForLoan,
      'loan_security': loanSecurity,
    };
    if (loanSecurity == 'guarantors' && guarantorLedgers.isNotEmpty) {
      payload['guarantors'] = guarantorLedgers.join(',');
    }
    if (loanSecurity == 'token' && collateralToken != null) {
      payload['collateral_token'] = collateralToken;
    }
    if (employmentStatus == 'employed') {
      payload['establishment'] = company ?? '';
      payload['department'] = department ?? '';
      payload['monthly_salary'] = monthlySalary ?? 0;
      payload['outstanding_loan'] = outstandingLoan ?? 0;
      payload['monthly_repayment'] = otherMonthlyRepayment ?? 0;
      payload['obligation'] = otherMonthlyRepayment ?? 0;
    }

    try {
      final response = await _dio.post(
        ApiEndpoints.membersLoanApplication,
        data: payload,
      );
      final data = response.data;
      if (response.statusCode == 200) {
        if (data is Map) return Map<String, dynamic>.from(data);
        return const {};
      }
      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }
      throw Exception('Unable to submit loan application');
    } on DioException catch (e) {
      throw _wrap(e, 'Unable to submit loan application');
    }
  }

  /// Cancel a pending loan application by reference id. Backend route
  /// expects the reference in the request body.
  Future<void> cancelApplication(String referenceId) async {
    final ref = referenceId.trim();
    if (ref.isEmpty) throw Exception('Missing loan reference');
    try {
      final response = await _dio.put(
        ApiEndpoints.membersLoanCancelRequest,
        data: {'reference_id': ref},
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
