class ObligationCategory {
  final String code;
  final String displayName;
  final bool isWithdrawable;
  final bool isLoanEligible;
  final bool isMandatory;
  final bool earnsInterest;
  final bool isShareBased;
  final int displayOrder;

  const ObligationCategory({
    required this.code,
    required this.displayName,
    required this.isWithdrawable,
    required this.isLoanEligible,
    required this.isMandatory,
    required this.earnsInterest,
    required this.isShareBased,
    required this.displayOrder,
  });

  factory ObligationCategory.fromJson(Map<String, dynamic> json) {
    return ObligationCategory(
      code:           json['code'] as String,
      displayName:    json['display_name'] as String,
      isWithdrawable: json['is_withdrawable'] == true || json['is_withdrawable'] == 1,
      isLoanEligible: json['is_loan_eligible'] == true || json['is_loan_eligible'] == 1,
      isMandatory:    json['is_mandatory'] == true || json['is_mandatory'] == 1,
      earnsInterest:  json['earns_interest'] == true || json['earns_interest'] == 1,
      isShareBased:   json['is_share_based'] == true || json['is_share_based'] == 1,
      displayOrder:   (json['display_order'] as num?)?.toInt() ?? 0,
    );
  }

  static List<ObligationCategory> get defaults => [
    ObligationCategory(code: '1523', displayName: 'Equity',    isWithdrawable: false, isLoanEligible: true,  isMandatory: true,  earnsInterest: false, isShareBased: true,  displayOrder: 1),
    ObligationCategory(code: '1524', displayName: 'Patronage', isWithdrawable: true,  isLoanEligible: true,  isMandatory: true,  earnsInterest: false, isShareBased: false, displayOrder: 2),
    ObligationCategory(code: '1525', displayName: 'Custom',    isWithdrawable: true,  isLoanEligible: true,  isMandatory: false, earnsInterest: false, isShareBased: false, displayOrder: 3),
    ObligationCategory(code: '1526', displayName: 'Fine',      isWithdrawable: false, isLoanEligible: false, isMandatory: false, earnsInterest: false, isShareBased: false, displayOrder: 4),
  ];

  /// Resolve display name for a given account type code, with fallback.
  static String resolveDisplayName(String? code, List<ObligationCategory> categories) {
    if (code == null) return 'Obligation';
    final cat = categories.firstWhere(
      (c) => c.code == code.trim(),
      orElse: () => defaults.firstWhere(
        (c) => c.code == code.trim(),
        orElse: () => ObligationCategory(code: code, displayName: 'Custom', isWithdrawable: false, isLoanEligible: false, isMandatory: false, earnsInterest: false, isShareBased: false, displayOrder: 99),
      ),
    );
    return cat.displayName;
  }

  /// Returns true if this category is share-based (never overdue).
  static bool isShareBasedCode(String? code, List<ObligationCategory> categories) {
    if (code == null) return false;
    final cat = categories.firstWhere(
      (c) => c.code == code.trim(),
      orElse: () => defaults.firstWhere(
        (c) => c.code == code.trim(),
        orElse: () => ObligationCategory(code: code, displayName: 'Custom', isWithdrawable: false, isLoanEligible: false, isMandatory: false, earnsInterest: false, isShareBased: false, displayOrder: 99),
      ),
    );
    return cat.isShareBased;
  }
}
