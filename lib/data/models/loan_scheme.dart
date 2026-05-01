import 'package:communal_mobile/core/utils/money.dart';

/// Cooperative-defined loan product. A scheme constrains the duration,
/// guarantor count, and interest a member sees on the application form.
///
/// Money fields here are *not* present today — the backend's loan_schemes
/// table tracks rate/duration/guarantor count but no min/max amount.
/// Caps come from cooperative-wide settings (loan_minimum_amount + the
/// access-control multiplier on member holdings), so the model only
/// surfaces the per-scheme product attributes.
class LoanScheme {
  LoanScheme({
    required this.id,
    required this.loanCode,
    required this.title,
    required this.category,
    required this.durationMonths,
    required this.interestRate,
    required this.serviceCharge,
    required this.numberOfGuarantors,
    required this.reGrantPeriod,
    required this.reGrantLimit,
    this.minDurationMonths,
    this.maxDurationMonths,
    this.interestType,
  });

  final String id;
  final String loanCode;
  final String title;
  final String category;
  /// Legacy single-value duration. Kept for one release while the
  /// backend writes both `duration` and the new
  /// `min_duration_months` / `max_duration_months` columns. Prefer
  /// {@link effectiveMinDuration} / {@link effectiveMaxDuration} for
  /// any new code.
  final int durationMonths;
  final double interestRate;
  final double serviceCharge;
  final int numberOfGuarantors;
  final int reGrantPeriod;
  final int reGrantLimit;

  /// Member-pickable duration window. Null on schemes that haven't
  /// been re-saved since the Phase 1 schema migration; callers should
  /// use {@link effectiveMinDuration} / {@link effectiveMaxDuration}
  /// to get sensible fallbacks.
  final int? minDurationMonths;
  final int? maxDurationMonths;

  /// Effective minimum duration (months) for the apply / calculator
  /// slider. Falls back to the legacy single-value `duration` for
  /// schemes that predate the min/max migration.
  int get effectiveMinDuration =>
      (minDurationMonths != null && minDurationMonths! > 0)
          ? minDurationMonths!
          : durationMonths;

  /// Effective maximum duration (months). Same fallback as above.
  int get effectiveMaxDuration =>
      (maxDurationMonths != null && maxDurationMonths! > 0)
          ? maxDurationMonths!
          : durationMonths;

  /// True when the scheme exposes a real range (min < max). Calculator
  /// + apply form unlock the slider only in this case; otherwise the
  /// duration is fixed and the slider is rendered read-only.
  bool get hasDurationRange => effectiveMaxDuration > effectiveMinDuration;

  /// `'1'` deducts interest up-front (member receives `amount - interest`),
  /// `'2'` adds interest to the principal (member repays `amount + interest`).
  /// Some cooperatives leave this null and let the member choose.
  final String? interestType;

  String get interestRateLabel => '${interestRate.toStringAsFixed(interestRate.truncateToDouble() == interestRate ? 0 : 2)}%';
  String get durationLabel {
    final lo = effectiveMinDuration;
    final hi = effectiveMaxDuration;
    if (lo == hi) return '$lo month${lo == 1 ? '' : 's'}';
    return '$lo – $hi months';
  }

  /// Convert to the `loan_data` JSON the backend store endpoint expects —
  /// it round-trips the entire scheme row server-side. Pass
  /// [pickedDurationMonths] when the member chose a duration within
  /// the scheme range so the backend's approval flow uses it rather
  /// than the scheme's max.
  Map<String, dynamic> toBackendJson({int? pickedDurationMonths}) => {
        'id': id,
        'loan_code': loanCode,
        'title': title,
        'category': category,
        // The backend approve flow now reads `loan_data.duration`
        // first, falling back to `scheme.max_duration_months` then
        // the legacy `duration` column. Sending the picked value
        // keeps the schedule materialisation honest.
        'duration': pickedDurationMonths ?? effectiveMaxDuration,
        'min_duration_months': effectiveMinDuration,
        'max_duration_months': effectiveMaxDuration,
        'interest_rate': interestRate,
        'service_charge': serviceCharge,
        'number_of_guarantors': numberOfGuarantors,
        're_grant_period': reGrantPeriod,
        're_grant_limit': reGrantLimit,
        if (interestType != null) 'interest_type': interestType,
      };

  factory LoanScheme.fromBackend(Map<String, dynamic> m) {
    final minRaw = m['min_duration_months'];
    final maxRaw = m['max_duration_months'];
    return LoanScheme(
      id: m['id']?.toString() ?? '',
      loanCode: m['loan_code']?.toString() ?? m['code']?.toString() ?? '',
      title: m['title']?.toString().trim() ?? '',
      category: m['category']?.toString().trim() ?? '',
      durationMonths: _asInt(m['duration']),
      minDurationMonths: minRaw == null ? null : _asInt(minRaw),
      maxDurationMonths: maxRaw == null ? null : _asInt(maxRaw),
      interestRate: _asDouble(m['interest_rate']),
      serviceCharge: _asDouble(m['service_charge']),
      numberOfGuarantors: _asInt(m['number_of_guarantors']),
      reGrantPeriod: _asInt(m['re_grant_period']),
      reGrantLimit: _asInt(m['re_grant_limit']),
      interestType: m['interest_type']?.toString(),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString().trim() ?? '') ??
        double.tryParse(v?.toString().trim() ?? '')?.toInt() ??
        0;
  }

  static double _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().trim() ?? '') ?? 0.0;
  }
}

/// Convenience: estimated monthly repayment for a `(principal, scheme)`
/// pair using the same arithmetic the backend applies on apply.
/// `principalMinor` is integer minor units of [currency].
int estimatedMonthlyRepaymentMinor({
  required int principalMinor,
  required LoanScheme scheme,
  required String interestType,
  required String currency,
}) {
  if (scheme.durationMonths <= 0 || principalMinor <= 0) return 0;
  final interest = (principalMinor * scheme.interestRate / 100).round();
  final total = interestType == '1'
      ? (principalMinor - interest)
      : (principalMinor + interest);
  return (total / scheme.durationMonths).round();
}

String estimatedMonthlyRepaymentLabel({
  required int principalMinor,
  required LoanScheme scheme,
  required String interestType,
  required String currency,
}) {
  final amount = estimatedMonthlyRepaymentMinor(
    principalMinor: principalMinor,
    scheme: scheme,
    interestType: interestType,
    currency: currency,
  );
  return Money(amount, currency).format();
}
