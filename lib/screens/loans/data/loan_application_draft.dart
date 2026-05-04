import 'package:communal_mobile/data/models/loan_scheme.dart';
import 'package:communal_mobile/data/models/member_search_result.dart';

/// Mutable, in-memory state that the three application steps pass to
/// each other through `GoRouter` `extra`. Persists for the duration of
/// the apply flow only — no Hive / SharedPreferences write — and is
/// thrown away once the success screen is shown or the user backs out.
class LoanApplicationDraft {
  LoanApplicationDraft({
    required this.scheme,
    required this.amountMajor,
    required this.currency,
    required this.interestType,
    required this.reasonForLoan,
    this.pickedDurationMonths,
    this.guarantors = const [],
  });

  /// Member-chosen duration within the scheme's [min..max] window.
  /// Null when the scheme has a single fixed term (no slider was
  /// shown). The repository falls back to [LoanScheme.effectiveMaxDuration]
  /// when null.
  final int? pickedDurationMonths;

  /// Scheme the member is applying under. Drives duration, guarantor
  /// count and interest rate downstream.
  final LoanScheme scheme;

  /// Amount in main currency units (e.g. 50000 for ₦50,000). Backend
  /// multiplies by 100 server-side, so we keep it as major here.
  final double amountMajor;

  /// ISO 4217 alpha-3 (kobo / cents inferred from this when needed).
  final String currency;

  /// `'1'` deduct-on-disbursal, `'2'` add-to-principal. Some schemes
  /// pin this; otherwise the member chooses on step 1.
  final String interestType;

  final String reasonForLoan;

  /// Guarantors picked in step 2. Empty until then.
  final List<MemberSearchResult> guarantors;

  LoanApplicationDraft copyWith({
    LoanScheme? scheme,
    double? amountMajor,
    String? currency,
    String? interestType,
    String? reasonForLoan,
    int? pickedDurationMonths,
    List<MemberSearchResult>? guarantors,
  }) {
    return LoanApplicationDraft(
      scheme: scheme ?? this.scheme,
      amountMajor: amountMajor ?? this.amountMajor,
      currency: currency ?? this.currency,
      interestType: interestType ?? this.interestType,
      reasonForLoan: reasonForLoan ?? this.reasonForLoan,
      pickedDurationMonths: pickedDurationMonths ?? this.pickedDurationMonths,
      guarantors: guarantors ?? this.guarantors,
    );
  }

  /// Effective duration the apply call should use — the member's
  /// pick if a slider was shown, otherwise the scheme's max.
  int get effectiveDurationMonths =>
      pickedDurationMonths ?? scheme.effectiveMaxDuration;
}
