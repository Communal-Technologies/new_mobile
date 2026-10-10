/// A sundry entry on a member's record: `credit` is money the cooperative is
/// holding for them, `debit` is a balance they still owe it.
class MemberSundry {
  const MemberSundry({
    required this.id,
    required this.category,
    required this.amountMinor,
    required this.currency,
    required this.description,
    required this.source,
    required this.reference,
    required this.status,
    required this.cooperativeId,
    this.createdAt,
  });

  final String id;
  final String category;
  final int amountMinor;
  final String currency;
  final String description;
  final String source;
  final String reference;
  final String status;
  final String cooperativeId;
  final DateTime? createdAt;

  bool get isCredit => category == 'credit';
  bool get isPending => status == 'pending';

  String get sourceLabel {
    switch (source) {
      case 'deduction_residual':
        return 'Payroll remainder';
      case 'closure_settlement':
        return 'Closure settlement';
      case 'member_removal':
        return 'Member removal';
      default:
        return source.isEmpty ? 'Raised by your cooperative' : source.replaceAll('_', ' ');
    }
  }

  factory MemberSundry.fromJson(Map<String, dynamic> json) {
    final created = json['created_at']?.toString();
    return MemberSundry(
      id: json['id']?.toString() ?? '',
      category: json['category']?.toString() ?? 'credit',
      amountMinor: _toMinor(json['amount']),
      currency: json['currency']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      cooperativeId: json['cooperative_id']?.toString() ?? '',
      createdAt: created == null ? null : DateTime.tryParse(created),
    );
  }
}

class MemberSundryPosition {
  const MemberSundryPosition({
    this.entries = const [],
    this.creditMinor = 0,
    this.debitMinor = 0,
    this.netMinor = 0,
    this.currency = '',
  });

  final List<MemberSundry> entries;
  final int creditMinor;
  final int debitMinor;
  final int netMinor;
  final String currency;

  bool get isEmpty => entries.isEmpty;
  bool get hasPosition => creditMinor != 0 || debitMinor != 0;

  factory MemberSundryPosition.fromJson(Map<String, dynamic> json) {
    final raw = json['entries'];
    return MemberSundryPosition(
      entries: raw is List
          ? raw
                .whereType<Map>()
                .map((e) => MemberSundry.fromJson(Map<String, dynamic>.from(e)))
                .toList()
          : const [],
      creditMinor: _toMinor(json['credit_minor']),
      debitMinor: _toMinor(json['debit_minor']),
      netMinor: _toMinor(json['net_minor']),
      currency: json['currency']?.toString() ?? '',
    );
  }
}

int _toMinor(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
