import 'package:communal_mobile/core/utils/money.dart';

/// One scheduled monthly payment row from
/// `GET /v1/loans/{loanId}/installments`.
///
/// Money fields are integer minor units of [currency] (kobo for NGN);
/// every render path uses [Money] to format. Status mirrors the
/// backend lifecycle in `loan_installments.status`:
///
///   - `pending`  — not yet due, or due but not yet swept
///   - `overdue`  — past due_date and not fully paid
///   - `fined`    — sub-state of overdue; a Fine-category obligation
///                  was written, [fineObligationId] points to it
///   - `paid`     — paid_minor >= total_due_minor
///   - `waived`   — admin override
class LoanInstallment {
  const LoanInstallment({
    required this.id,
    required this.sequence,
    required this.dueDate,
    required this.principalMinor,
    required this.interestMinor,
    required this.totalDueMinor,
    required this.paidMinor,
    required this.status,
    required this.currency,
    this.paidAt,
    this.fineObligationId,
  });

  final String id;
  final int sequence;
  final DateTime dueDate;
  final int principalMinor;
  final int interestMinor;
  final int totalDueMinor;
  final int paidMinor;
  final String status;
  final DateTime? paidAt;
  final String? fineObligationId;
  final String currency;

  bool get isPaid => status == 'paid';
  bool get isOverdue => status == 'overdue' || status == 'fined';
  bool get isOpen => status != 'paid' && status != 'waived';
  int get outstandingMinor =>
      totalDueMinor - paidMinor < 0 ? 0 : totalDueMinor - paidMinor;

  String get totalDueLabel => Money(totalDueMinor, currency).format();
  String get paidLabel => Money(paidMinor, currency).format();
  String get outstandingLabel => Money(outstandingMinor, currency).format();
  String get principalLabel => Money(principalMinor, currency).format();
  String get interestLabel => Money(interestMinor, currency).format();

  factory LoanInstallment.fromJson(Map<String, dynamic> m, {String fallbackCurrency = 'NGN'}) {
    return LoanInstallment(
      id: (m['id'] ?? '').toString(),
      sequence: _asInt(m['sequence']),
      dueDate: DateTime.tryParse((m['due_date'] ?? '').toString()) ?? DateTime.now(),
      principalMinor: _asInt(m['principal_minor']),
      interestMinor: _asInt(m['interest_minor']),
      totalDueMinor: _asInt(m['total_due_minor']),
      paidMinor: _asInt(m['paid_minor']),
      status: (m['status'] ?? 'pending').toString(),
      paidAt: DateTime.tryParse((m['paid_at'] ?? '').toString()),
      fineObligationId: m['fine_obligation_id']?.toString().isNotEmpty == true
          ? m['fine_obligation_id'].toString()
          : null,
      currency: ((m['currency'] ?? fallbackCurrency).toString().trim().isEmpty
              ? fallbackCurrency
              : m['currency'].toString())
          .toUpperCase(),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString().trim() ?? '') ??
        double.tryParse(v?.toString().trim() ?? '')?.toInt() ??
        0;
  }
}
