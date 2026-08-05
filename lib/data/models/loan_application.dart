import 'package:intl/intl.dart';

import 'package:communal_mobile/core/utils/money.dart';

/// Lifecycle status of a [LoanApplication]. Backend stores as a numeric
/// string in `loan_applications.status` — we reverse-resolve here so the
/// UI can switch on a sealed enum instead of magic numbers.
enum LoanStatus {
  pending, // 0
  approved, // 1
  declined, // 3
  cancelled, // 4
  unknown;

  static LoanStatus fromCode(dynamic raw) {
    final code = raw?.toString().trim();
    switch (code) {
      case '0':
        return LoanStatus.pending;
      case '1':
        return LoanStatus.approved;
      case '3':
        return LoanStatus.declined;
      case '4':
        return LoanStatus.cancelled;
    }
    return LoanStatus.unknown;
  }

  String get label {
    switch (this) {
      case LoanStatus.pending:
        return 'Pending';
      case LoanStatus.approved:
        return 'Active';
      case LoanStatus.declined:
        return 'Declined';
      case LoanStatus.cancelled:
        return 'Cancelled';
      case LoanStatus.unknown:
        return 'Unknown';
    }
  }
}

/// Member-facing loan application. Money fields are integer minor units
/// of [currency] (kobo for NGN) — same convention as
/// [Obligation] / the backend `loan_applications` table.
class LoanApplication {
  LoanApplication({
    required this.id,
    required this.referenceId,
    required this.loanCode,
    required this.status,
    required this.amountMinor,
    required this.amountPaidMinor,
    required this.monthlyRepaymentMinor,
    required this.interestMinor,
    required this.currency,
    required this.guarantors,
    required this.createdAt,
    this.dateApproved,
    this.dueDate,
    this.reasonForLoan,
    this.broughtForward = false,
    this.loanTitle = '',
    this.declineNote,
  });

  final String id;
  final String referenceId;
  final String loanCode;

  /// Human-readable scheme title (e.g. "Welfare Loan"). Backend joins
  /// LoanScheme.title onto the loan list/detail response so we don't show
  /// the raw `loan_code` on confirm screens and receipts. Falls back to
  /// the code when the scheme is missing.
  final String loanTitle;

  /// Best-effort display label: title when populated, otherwise code,
  /// otherwise reference. Use this everywhere a loan needs a human name.
  String get displayLabel {
    final t = loanTitle.trim();
    if (t.isNotEmpty) return t;
    final c = loanCode.trim();
    if (c.isNotEmpty) return c;
    return referenceId;
  }

  final LoanStatus status;
  final int amountMinor;
  final int amountPaidMinor;
  final int monthlyRepaymentMinor;
  final int interestMinor;
  final String currency;
  final List<String> guarantors;
  final DateTime createdAt;
  final DateTime? dateApproved;
  final DateTime? dueDate;
  final String? reasonForLoan;
  final bool broughtForward;

  /// Admin's reason when the loan was declined. Surfaced on the loan
  /// detail screen for status='3' applications instead of repayment
  /// history (a declined loan never has any).
  final String? declineNote;

  int get balanceMinor {
    final remaining = amountMinor - amountPaidMinor;
    return remaining < 0 ? 0 : remaining;
  }

  double get repaymentProgress {
    if (amountMinor <= 0) return 0;
    final p = amountPaidMinor / amountMinor;
    if (p < 0) return 0;
    if (p > 1) return 1;
    return p;
  }

  String get amountLabel => Money(amountMinor, currency).format();
  String get balanceLabel => Money(balanceMinor, currency).format();
  String get monthlyRepaymentLabel =>
      Money(monthlyRepaymentMinor, currency).format();
  String get progressLabel =>
      '${(repaymentProgress * 100).toStringAsFixed(0)}%';

  String? get dueDateLabel =>
      dueDate == null ? null : DateFormat('MMM dd, yyyy').format(dueDate!);
  String get createdAtLabel => DateFormat('MMM dd, yyyy').format(createdAt);

  factory LoanApplication.fromBackend(
    Map<String, dynamic> m, {
    String? fallbackCurrency,
  }) {
    final guarantorsRaw = m['guarantors']?.toString().trim() ?? '';
    final guarantors = guarantorsRaw.isEmpty
        ? const <String>[]
        : guarantorsRaw
              .split(RegExp(r'[,;|\s]+'))
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList();
    final currency =
        (m['currency']?.toString().trim().isNotEmpty == true
                ? m['currency'].toString()
                : (fallbackCurrency ?? 'NGN'))
            .toUpperCase();

    return LoanApplication(
      id: m['id']?.toString() ?? '',
      referenceId: m['reference_id']?.toString() ?? '',
      loanCode: m['loan_code']?.toString() ?? '',
      loanTitle: m['loan_title']?.toString() ?? '',
      status: LoanStatus.fromCode(m['status']),
      amountMinor: _asInt(m['amount']),
      amountPaidMinor: _asInt(m['amount_paid']),
      monthlyRepaymentMinor: _asInt(m['monthly_repayment']),
      interestMinor: _asInt(m['interest']),
      currency: currency,
      guarantors: guarantors,
      createdAt: _parseDate(m['created_at']) ?? DateTime.now(),
      dateApproved: _parseDate(m['date_approved']),
      dueDate: _parseDate(m['due_date']),
      reasonForLoan: m['reason_for_loan']?.toString(),
      broughtForward:
          m['brought_forward']?.toString() == '1' ||
          m['brought_forward'] == true,
      declineNote: m['decline_note']?.toString(),
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
