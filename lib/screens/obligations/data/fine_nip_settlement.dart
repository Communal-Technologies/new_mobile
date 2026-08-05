/// Carried through NIP verify → receipt so a successful transfer can post
/// the fine payment. Mirrors ObligationNipSettlement but targets
/// ObligationFine records rather than FinancialObligation rows.
class FineNipSettlement {
  const FineNipSettlement({
    required this.cashRepositoryId,
    required this.cooperativeId,
    required this.fineId,
    required this.fineDescription,
    required this.amountMinor,
    this.currency = 'NGN',
  });

  final String cashRepositoryId;
  final String cooperativeId;
  final String fineId;
  final String fineDescription;
  final int amountMinor;
  final String currency;

  Map<String, dynamic> toJson() => {
        'cash_repository_id': cashRepositoryId,
        'cooperative_id': cooperativeId,
        'fine_id': fineId,
        'fine_description': fineDescription,
        'amount_minor': amountMinor,
        'currency': currency,
      };

  static FineNipSettlement? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = m['cash_repository_id']?.toString().trim() ?? '';
    final coop = m['cooperative_id']?.toString().trim() ?? '';
    final fineId = m['fine_id']?.toString().trim() ?? '';
    if (id.isEmpty || coop.isEmpty || fineId.isEmpty) return null;

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

    return FineNipSettlement(
      cashRepositoryId: id,
      cooperativeId: coop,
      fineId: fineId,
      fineDescription: m['fine_description']?.toString().trim() ?? 'Fine payment',
      amountMinor: amountMinor,
      currency: currency,
    );
  }
}
