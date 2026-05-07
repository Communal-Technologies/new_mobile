import 'package:intl/intl.dart';

/// A member's request to redeem a portion of their patronage or custom
/// obligation balance.  Status lifecycle: pending → approved | declined,
/// or revoked by the member before the admin acts.
class ObligationWithdrawalRequest {
  const ObligationWithdrawalRequest({
    required this.id,
    required this.cooperativeId,
    required this.ledgerNumber,
    required this.accountCode,
    required this.amountMinor,
    required this.currency,
    required this.status,
    this.note,
    this.declineReason,
    required this.createdAt,
    this.approvedAt,
    this.declinedAt,
  });

  final String id;
  final String cooperativeId;
  final String ledgerNumber;

  /// The obligation account_code this withdrawal targets.
  final String accountCode;

  /// Amount in integer minor units (kobo for NGN).
  final int amountMinor;

  final String currency;

  /// '0'=pending  '1'=approved  '2'=declined  '3'=revoked_by_member
  final String status;

  final String? note;
  final String? declineReason;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? declinedAt;

  // ── Derived ──────────────────────────────────────────────────────────── //

  bool get isPending  => status == '0';
  bool get isApproved => status == '1';
  bool get isDeclined => status == '2';
  bool get isRevoked  => status == '3';

  String get statusLabel {
    switch (status) {
      case '1': return 'Approved';
      case '2': return 'Declined';
      case '3': return 'Revoked';
      default:  return 'Pending';
    }
  }

  String get amountLabel {
    final major = amountMinor / 100;
    final fmt = NumberFormat('#,##0.##', 'en_US');
    final symbol = currency == 'NGN' ? '₦' : currency;
    return '$symbol${fmt.format(major)}';
  }

  String get createdAtLabel =>
      DateFormat('dd MMM yyyy').format(createdAt.toLocal());

  // ── Factory ──────────────────────────────────────────────────────────── //

  factory ObligationWithdrawalRequest.fromJson(Map<String, dynamic> m) {
    return ObligationWithdrawalRequest(
      id:            m['id']?.toString() ?? '',
      cooperativeId: m['cooperative_id']?.toString() ?? '',
      ledgerNumber:  m['ledger_number']?.toString() ?? '',
      accountCode:   m['account_code']?.toString() ?? '',
      amountMinor:   _parseInt(m['amount']),
      currency:      m['currency']?.toString() ?? 'NGN',
      status:        m['status']?.toString() ?? '0',
      note:          m['note']?.toString(),
      declineReason: m['decline_reason']?.toString(),
      createdAt: DateTime.tryParse(m['created_at']?.toString() ?? '') ??
          DateTime.now(),
      approvedAt: m['approved_at'] != null
          ? DateTime.tryParse(m['approved_at'].toString())
          : null,
      declinedAt: m['declined_at'] != null
          ? DateTime.tryParse(m['declined_at'].toString())
          : null,
    );
  }

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString().trim() ?? '') ?? 0;
  }
}
