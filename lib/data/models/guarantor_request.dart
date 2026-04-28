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
    return GuarantorRequest(
      id: m['id']?.toString() ?? '',
      applicantName: m['name']?.toString().trim() ?? '',
      guarantorLedger: m['guarantor']?.toString() ?? '',
      loanRef: m['ref']?.toString() ?? '',
      amountMinor: _asInt(m['amount']),
      currency: currency,
      status: m['status']?.toString().trim() ?? '0',
      createdAt: _parseDate(m['created_at']) ?? DateTime.now(),
    );
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
