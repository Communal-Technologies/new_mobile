/// Carried through NIP verify → receipt so a successful transfer can post
/// the obligation payment. Money is integer minor units of [currency]
/// (kobo for NGN), matching the backend ledger and the rest of the
/// app's money convention. The legacy `amount_naira` shape on the JSON
/// payload is still accepted by [tryFromJson] for back-compat.
class ObligationNipSettlement {
  const ObligationNipSettlement({
    required this.cashRepositoryId,
    required this.cooperativeId,
    required this.obligationAccountCode,
    required this.obligationTitle,
    required this.obligationCategory,
    required this.amountMinor,
    this.currency = 'NGN',
  });

  final String cashRepositoryId;
  final String cooperativeId;
  final String obligationAccountCode;
  final String obligationTitle;
  final String obligationCategory;
  final int amountMinor;
  final String currency;

  Map<String, dynamic> toJson() => {
        'cash_repository_id': cashRepositoryId,
        'cooperative_id': cooperativeId,
        'obligation_account_code': obligationAccountCode,
        'obligation_title': obligationTitle,
        'obligation_category': obligationCategory,
        'amount_minor': amountMinor,
        'currency': currency,
      };

  static ObligationNipSettlement? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = m['cash_repository_id']?.toString().trim() ?? '';
    final coop = m['cooperative_id']?.toString().trim() ?? '';
    final code = m['obligation_account_code']?.toString().trim() ?? '';
    final title = m['obligation_title']?.toString().trim() ?? '';
    final cat = m['obligation_category']?.toString().trim() ?? '';
    if (id.isEmpty || coop.isEmpty || code.isEmpty) return null;

    final currency =
        (m['currency']?.toString().trim().isNotEmpty == true
                ? m['currency'].toString()
                : 'NGN')
            .toUpperCase();

    int amountMinor = 0;
    final rawMinor = m['amount_minor'];
    if (rawMinor is num) {
      amountMinor = rawMinor.toInt();
    } else if (rawMinor != null) {
      amountMinor = int.tryParse(rawMinor.toString()) ?? 0;
    }
    if (amountMinor == 0) {
      // Back-compat: older payloads carried `amount_naira` as a double.
      // Re-derive minor units assuming NGN's 100:1 factor.
      final legacy = m['amount_naira'];
      if (legacy is num) {
        amountMinor = (legacy.toDouble() * 100).round();
      } else if (legacy != null) {
        amountMinor =
            ((double.tryParse(legacy.toString()) ?? 0) * 100).round();
      }
    }

    return ObligationNipSettlement(
      cashRepositoryId: id,
      cooperativeId: coop,
      obligationAccountCode: code,
      obligationTitle: title.isEmpty ? 'Obligation' : title,
      obligationCategory: cat.isEmpty ? 'Obligation' : cat,
      amountMinor: amountMinor,
      currency: currency,
    );
  }
}
