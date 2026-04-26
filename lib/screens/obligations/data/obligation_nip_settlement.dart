/// Carried through NIP verify → receipt so a successful transfer can post obligation payment.
class ObligationNipSettlement {
  const ObligationNipSettlement({
    required this.cashRepositoryId,
    required this.cooperativeId,
    required this.obligationAccountCode,
    required this.obligationTitle,
    required this.obligationCategory,
    required this.amountNaira,
  });

  final String cashRepositoryId;
  final String cooperativeId;
  final String obligationAccountCode;
  final String obligationTitle;
  final String obligationCategory;
  final double amountNaira;

  Map<String, dynamic> toJson() => {
        'cash_repository_id': cashRepositoryId,
        'cooperative_id': cooperativeId,
        'obligation_account_code': obligationAccountCode,
        'obligation_title': obligationTitle,
        'obligation_category': obligationCategory,
        'amount_naira': amountNaira,
      };

  static ObligationNipSettlement? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = m['cash_repository_id']?.toString().trim() ?? '';
    final coop = m['cooperative_id']?.toString().trim() ?? '';
    final code = m['obligation_account_code']?.toString().trim() ?? '';
    final title = m['obligation_title']?.toString().trim() ?? '';
    final cat = m['obligation_category']?.toString().trim() ?? '';
    final amt = m['amount_naira'];
    final amountNaira = amt is num ? amt.toDouble() : double.tryParse('$amt') ?? 0;
    if (id.isEmpty || coop.isEmpty || code.isEmpty) return null;
    return ObligationNipSettlement(
      cashRepositoryId: id,
      cooperativeId: coop,
      obligationAccountCode: code,
      obligationTitle: title.isEmpty ? 'Obligation' : title,
      obligationCategory: cat.isEmpty ? 'Obligation' : cat,
      amountNaira: amountNaira,
    );
  }
}
