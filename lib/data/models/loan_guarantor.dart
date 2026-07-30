/// One row from `GET /members/loan/guarantors/for-loan/{loanRef}`.
/// Drives the per-guarantor card on the applicant's loan-detail
/// screen — name, current approval status, expiry countdown, and
/// the rate-limit timestamp the Remind button keys off.
class LoanGuarantor {
  LoanGuarantor({
    required this.approvalId,
    required this.ledgerNumber,
    required this.name,
    required this.status,
    this.expiresAt,
    this.lastRemindedAt,
    this.respondedAt,
  });

  final String approvalId;
  final String ledgerNumber;
  final String name;

  /// `'0'` pending, `'1'` approved, `'2'` declined / declined-by-
  /// expiry / declined-by-replacement.
  final String status;

  final DateTime? expiresAt;
  final DateTime? lastRemindedAt;
  final DateTime? respondedAt;

  bool get isPending => status == '0';
  bool get isApproved => status == '1';
  bool get isDeclined => status == '2';
  bool get isExpired =>
      isPending && expiresAt != null && expiresAt!.isBefore(DateTime.now());

  /// True when the applicant must wait before they can send another
  /// reminder. Backend mirrors this rule (24h since last_reminded_at);
  /// this is the client-side mirror so the button can render
  /// `disabled` rather than letting the user tap → 429.
  bool get reminderRateLimited {
    if (lastRemindedAt == null) return false;
    return DateTime.now().difference(lastRemindedAt!).inHours < 24;
  }

  factory LoanGuarantor.fromJson(Map<String, dynamic> m) {
    return LoanGuarantor(
      approvalId: m['approval_id']?.toString() ?? '',
      ledgerNumber: m['ledger_number']?.toString() ?? '',
      name: m['name']?.toString() ?? '',
      status: m['status']?.toString() ?? '0',
      expiresAt: _parse(m['expires_at']),
      lastRemindedAt: _parse(m['last_reminded_at']),
      respondedAt: _parse(m['responded_at']),
    );
  }

  static DateTime? _parse(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
}

class LoanGuarantorList {
  LoanGuarantorList({
    required this.guarantors,
    required this.approved,
    required this.pending,
    required this.declined,
  });

  final List<LoanGuarantor> guarantors;
  final int approved;
  final int pending;
  final int declined;

  int get total => guarantors.length;
  bool get allResponded => pending == 0 && total > 0;

  factory LoanGuarantorList.fromJson(Map<String, dynamic> m) {
    final list = (m['guarantors'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => LoanGuarantor.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
    final summary = (m['summary'] is Map)
        ? Map<String, dynamic>.from(m['summary'])
        : <String, dynamic>{};
    return LoanGuarantorList(
      guarantors: list,
      approved: _asInt(summary['approved']),
      pending: _asInt(summary['pending']),
      declined: _asInt(summary['declined']),
    );
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}
