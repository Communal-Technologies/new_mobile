import 'package:intl/intl.dart';

import 'package:communal_mobile/core/utils/money.dart';

/// One incoming "please stand as my guarantor" request shown in the
/// guarantor inbox. Backed by `guarantors_loan_approvals` joined with
/// `loan_applications` (see `GuarantorsLoanApprovalController::index`).
class GuarantorRequest {
  GuarantorRequest({
    required this.id,
    required this.applicantName,
    required this.guarantorLedger,
    required this.loanRef,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.createdAt,
    this.expiresAt,
    this.lastRemindedAt,
    this.reasonForLoan,
    this.interestType,
    this.monthlyRepayment,
    this.schemeTitle,
    this.schemeInterestRate,
    this.schemeDurationMonths,
    this.schemeServiceChargeMinor,
    this.schemeNumberOfGuarantors,
    this.coGuarantorsRemaining,
  });

  final String id;
  final String applicantName;
  final String guarantorLedger;
  final String loanRef;
  final int amountMinor;
  final String currency;

  /// `'0'` = pending, `'1'` = accepted, anything else = declined.
  final String status;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? lastRemindedAt;

  /// Loan-detail fields used by the guarantor-detail screen so the
  /// member sees what they're actually backing before they accept.
  /// Optional because legacy `index` responses omitted them and we
  /// don't want to crash on stale rows.
  final String? reasonForLoan;
  final String? interestType;
  final num? monthlyRepayment;
  final String? schemeTitle;
  final num? schemeInterestRate;
  final int? schemeDurationMonths;
  final int? schemeServiceChargeMinor;
  final int? schemeNumberOfGuarantors;
  final int? coGuarantorsRemaining;

  bool get isPending => status == '0';
  bool get isAccepted => status == '1';

  String get amountLabel => Money(amountMinor, currency).format();
  String get createdAtLabel => DateFormat('MMM dd, yyyy').format(createdAt);
  String get statusLabel {
    if (isPending) return 'Pending';
    if (isAccepted) return 'Accepted';
    return 'Declined';
  }

  factory GuarantorRequest.fromBackend(
    Map<String, dynamic> m, {
    String? fallbackCurrency,
  }) {
    final currency = (m['currency']?.toString().trim().isNotEmpty == true
            ? m['currency'].toString()
            : (fallbackCurrency ?? 'NGN'))
        .toUpperCase();
    final loan = (m['loan'] is Map) ? Map<String, dynamic>.from(m['loan']) : null;
    return GuarantorRequest(
      id: m['id']?.toString() ?? '',
      applicantName: m['name']?.toString().trim() ?? '',
      guarantorLedger: m['guarantor']?.toString() ?? '',
      loanRef: m['ref']?.toString() ?? '',
      amountMinor: _asInt(m['amount']),
      currency: currency,
      status: m['status']?.toString().trim() ?? '0',
      createdAt: _parseDate(m['created_at']) ?? DateTime.now(),
      expiresAt: _parseDate(m['expires_at']),
      lastRemindedAt: _parseDate(m['last_reminded_at']),
      reasonForLoan: loan?['reason_for_loan']?.toString(),
      interestType: loan?['interest_type']?.toString(),
      monthlyRepayment: loan?['monthly_repayment'] is num
          ? loan!['monthly_repayment'] as num
          : num.tryParse(loan?['monthly_repayment']?.toString() ?? ''),
      schemeTitle: loan?['scheme_title']?.toString(),
      schemeInterestRate: loan?['scheme_interest_rate'] is num
          ? loan!['scheme_interest_rate'] as num
          : num.tryParse(loan?['scheme_interest_rate']?.toString() ?? ''),
      schemeDurationMonths: _asNullableInt(loan?['scheme_duration_months']),
      schemeServiceChargeMinor: _asNullableInt(loan?['scheme_service_charge_minor']),
      schemeNumberOfGuarantors: _asNullableInt(loan?['scheme_number_of_guarantors']),
      coGuarantorsRemaining: _asNullableInt(loan?['co_guarantors_remaining']),
    );
  }

  static int? _asNullableInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString().trim());
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString().trim() ?? '') ??
        double.tryParse(v?.toString().trim() ?? '')?.toInt() ??
        0;
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}
