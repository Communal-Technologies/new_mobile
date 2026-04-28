import 'package:communal_mobile/core/utils/money.dart';

/// One row of the cooperative's `interest_types` setting. The
/// dashboard's loan settings page edits this list — the mobile member
/// only sees the entries with `enabled == true`, and the one with
/// `isDefault == true` is what new applications are stamped with.
class InterestTypeOption {
  const InterestTypeOption({
    required this.id,
    required this.value,
    required this.title,
    required this.note,
    required this.enabled,
    required this.isDefault,
  });

  final String id;

  /// `'1'` = deduct-on-disbursal, `'2'` = add-to-principal. Sent back
  /// as `interest_type` on the apply call.
  final String value;
  final String title;
  final String note;
  final bool enabled;
  final bool isDefault;

  factory InterestTypeOption.fromJson(Map<String, dynamic> m) {
    bool asBool(dynamic v) =>
        v == true || v == 1 || v == '1' || v == 'true';
    return InterestTypeOption(
      id: m['id']?.toString() ?? '',
      value: m['value']?.toString() ?? '',
      title: m['title']?.toString() ?? '',
      note: m['note']?.toString() ?? '',
      enabled: asBool(m['enabled']),
      isDefault: asBool(m['default']),
    );
  }
}

/// Member-side eligibility envelope returned by
/// `/v1/members/loan/eligibility/{cooperative_id}`. Powers the loan
/// application screen's slider bounds and the read-only interest
/// treatment card.
class LoanEligibility {
  const LoanEligibility({
    required this.cooperativeId,
    required this.currency,
    required this.minAmountMinor,
    required this.maxAmountMinor,
    required this.interestTypes,
  });

  final String cooperativeId;
  final String currency;

  /// Cooperative-set minimum loan amount, in integer minor units.
  final int minAmountMinor;

  /// Maximum the member is currently eligible for — sum of their
  /// holdings across the cooperative's loan-eligible obligation
  /// categories. In integer minor units.
  final int maxAmountMinor;

  final List<InterestTypeOption> interestTypes;

  /// The cooperative's chosen default interest treatment, falling back
  /// to the first enabled one if no row is flagged as default.
  InterestTypeOption? get defaultInterestType {
    InterestTypeOption? def;
    InterestTypeOption? firstEnabled;
    for (final t in interestTypes) {
      if (!t.enabled) continue;
      firstEnabled ??= t;
      if (t.isDefault) {
        def = t;
        break;
      }
    }
    return def ?? firstEnabled;
  }

  String get minLabel => Money(minAmountMinor, currency).format();
  String get maxLabel => Money(maxAmountMinor, currency).format();

  factory LoanEligibility.fromJson(Map<String, dynamic> m) {
    final raw = m['interest_types'];
    final list = <InterestTypeOption>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          list.add(InterestTypeOption.fromJson(
              Map<String, dynamic>.from(item)));
        }
      }
    }
    return LoanEligibility(
      cooperativeId: m['cooperative_id']?.toString() ?? '',
      currency: (m['currency']?.toString().isNotEmpty == true
              ? m['currency'].toString()
              : 'NGN')
          .toUpperCase(),
      minAmountMinor: _asInt(m['min_amount_minor']),
      maxAmountMinor: _asInt(m['max_amount_minor']),
      interestTypes: list,
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
