import 'package:communal_mobile/core/utils/money.dart';

/// Cooperative-defined loan scheme. A scheme constrains the duration,
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
    this.allowMemberDuration = false,
    this.memberDurationRateMode,
    this.memberDurationRateStep,
    this.interestType,
  });

  final String id;
  final String loanCode;
  final String title;
  final String category;
  /// Legacy single-value duration. Kept for one release while the
  /// backend writes both `duration` and the new
  /// `min_duration_months` / `max_duration_months` columns. Prefer
  /// [effectiveMinDuration] / [effectiveMaxDuration] for
  /// any new code.
  final int durationMonths;
  final double interestRate;
  final double serviceCharge;
  final int numberOfGuarantors;
  final int reGrantPeriod;
  final int reGrantLimit;

  /// Member-pickable duration window. Null on schemes that haven't
  /// been re-saved since the Phase 1 schema migration; callers should
  /// use [effectiveMinDuration] / [effectiveMaxDuration]
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

  /// Admin opt-in: members may choose their own term inside the scheme
  /// window. Loans taken this way are never re-granted, and the interest
  /// rate escalates with the term via [memberDurationRateMode] /
  /// [memberDurationRateStep].
  final bool allowMemberDuration;

  /// `'1'` adds [memberDurationRateStep] percentage points per extra month;
  /// `'2'` scales the base rate by that many percent per extra month.
  final String? memberDurationRateMode;
  final double? memberDurationRateStep;

  /// True when the scheme exposes a real range (min < max).
  bool get hasDurationRange => effectiveMaxDuration > effectiveMinDuration;

  /// The member may only move the term when the admin opted in AND the
  /// window is a real range.
  bool get memberCanPickDuration => allowMemberDuration && hasDurationRange;

  /// Interest rate a member is quoted for [months], mirroring the
  /// backend's effectiveInterestRate so the app never shows a rate the
  /// service would not apply.
  double rateForDuration(int months) {
    if (!allowMemberDuration || memberDurationRateStep == null) {
      return interestRate;
    }
    final extra = months - effectiveMinDuration;
    if (extra <= 0) return interestRate;
    final step = memberDurationRateStep!;
    final rate = memberDurationRateMode == '2'
        ? interestRate * (1 + (step / 100) * extra)
        : interestRate + step * extra;
    return rate.clamp(0, 100).toDouble();
  }

  String rateLabelForDuration(int months) {
    final r = rateForDuration(months);
    return '${r.toStringAsFixed(r.truncateToDouble() == r ? 0 : 2)}%';
  }

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
        'duration': pickedDurationMonths ?? effectiveMaxDuration,
        'min_duration_months': effectiveMinDuration,
        'max_duration_months': effectiveMaxDuration,
        'allow_member_duration': allowMemberDuration ? '1' : '0',
        if (memberDurationRateMode != null)
          'member_duration_rate_mode': memberDurationRateMode,
        if (memberDurationRateStep != null)
          'member_duration_rate_step': memberDurationRateStep,
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
      allowMemberDuration:
          m['allow_member_duration']?.toString().trim() == '1',
      memberDurationRateMode:
          m['member_duration_rate_mode']?.toString().trim().isEmpty ?? true
              ? null
              : m['member_duration_rate_mode'].toString().trim(),
      memberDurationRateStep: m['member_duration_rate_step'] == null
          ? null
          : _asDouble(m['member_duration_rate_step']),
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
/// `principalMinor` is integer minor units of [currency]. Pass
/// [durationMonths] when the member picked a term so the escalated rate
/// and the picked term are both reflected.
int estimatedMonthlyRepaymentMinor({
  required int principalMinor,
  required LoanScheme scheme,
  required String interestType,
  required String currency,
  int? durationMonths,
}) {
  final months = durationMonths ?? scheme.durationMonths;
  if (months <= 0 || principalMinor <= 0) return 0;
  final interest =
      (principalMinor * scheme.rateForDuration(months) / 100).round();
  // Deduct-now ('1'): interest is taken upfront, member repays the FULL
  // principal. Add-to-balance ('2'): repay principal + interest.
  final total = interestType == '1'
      ? principalMinor
      : (principalMinor + interest);
  return (total / months).round();
}

String estimatedMonthlyRepaymentLabel({
  required int principalMinor,
  required LoanScheme scheme,
  required String interestType,
  required String currency,
  int? durationMonths,
}) {
  final amount = estimatedMonthlyRepaymentMinor(
    principalMinor: principalMinor,
    scheme: scheme,
    interestType: interestType,
    currency: currency,
    durationMonths: durationMonths,
  );
  return Money(amount, currency).format();
}
