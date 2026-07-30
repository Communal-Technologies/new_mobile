/// Carried through NIP verify → receipt so a successful transfer can
/// post the loan repayment. Mirrors [ObligationNipSettlement] for the
/// loan flow. Money is integer minor units of [currency] (kobo for
/// NGN), matching the backend ledger.
class LoanNipSettlement {
  const LoanNipSettlement({
    required this.cashRepositoryId,
    required this.cooperativeId,
    required this.loanId,
    required this.loanCode,
    required this.amountMinor,
    this.loanTitle = '',
    this.currency = 'NGN',
  });

  final String cashRepositoryId;
  final String cooperativeId;
  final String loanId;
  final String loanCode;

  /// Scheme name, so the receipt and ledger can name the loan being repaid
  /// rather than showing only its code.
  final String loanTitle;
  final int amountMinor;
  final String currency;

  Map<String, dynamic> toJson() => {
    'cash_repository_id': cashRepositoryId,
    'cooperative_id': cooperativeId,
    'loan_id': loanId,
    'loan_code': loanCode,
    'loan_title': loanTitle,
    'amount_minor': amountMinor,
    'currency': currency,
  };

  static LoanNipSettlement? tryFromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = m['cash_repository_id']?.toString().trim() ?? '';
    final coop = m['cooperative_id']?.toString().trim() ?? '';
    final loanId = m['loan_id']?.toString().trim() ?? '';
    if (id.isEmpty || coop.isEmpty || loanId.isEmpty) return null;

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

    return LoanNipSettlement(
      cashRepositoryId: id,
      cooperativeId: coop,
      loanId: loanId,
      loanCode: m['loan_code']?.toString().trim() ?? '',
      loanTitle: m['loan_title']?.toString().trim() ?? '',
      amountMinor: amountMinor,
      currency: currency,
    );
  }
}
