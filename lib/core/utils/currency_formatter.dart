import 'money.dart';

/// Currency-aware money formatter. Prefer this over the deprecated
/// `formatNairaFromKobo*` helpers below, which hardcode NGN.
class CurrencyFormatter {
  /// Format an integer-minor amount for [currency] with the symbol prefix.
  /// Always shows the canonical number of decimals (₦25,000.00, ¥1,500, …).
  static String formatFromMinor(int amountMinor, String currency) =>
      Money(amountMinor, currency).format();

  /// Same as [formatFromMinor] but without the currency symbol.
  static String formatFromMinorNoSymbol(int amountMinor, String currency) =>
      Money(amountMinor, currency).format(symbol: false);

  // -------------------------------------------------------------------------
  // Deprecated NGN-only helpers — preserved so legacy call sites still build.
  // Do NOT use these for any non-NGN flow.
  // -------------------------------------------------------------------------

  /// @Deprecated Use [formatFromMinor] with currency 'NGN' (or the user's
  /// resolved currency). This rounds to whole naira, which is wrong for
  /// non-zero kobo amounts.
  @Deprecated('Use CurrencyFormatter.formatFromMinor(amount, currency).')
  static String formatNairaFromKobo(int kobo) {
    final naira = (kobo / 100).round();
    return formatNaira(naira);
  }

  /// @Deprecated Use [formatFromMinor] with currency 'NGN'.
  @Deprecated('Use CurrencyFormatter.formatFromMinor(amount, currency).')
  static String formatNairaFromKoboWithDecimals(int kobo) =>
      Money(kobo, 'NGN').format();

  /// @Deprecated Use [formatFromMinor] with currency 'NGN' (note the input
  /// type — this helper takes whole naira, not kobo).
  @Deprecated('Use CurrencyFormatter.formatFromMinor(amount, currency).')
  static String formatNaira(int amount) {
    final neg = amount < 0;
    final abs = amount.abs();
    final buf = StringBuffer('₦');
    if (neg) buf.write('-');
    buf.write(_digitsWithThousandsSeparators(abs));
    return buf.toString();
  }

  static String _digitsWithThousandsSeparators(int value) {
    final amountStr = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < amountStr.length; i++) {
      if (i > 0 && (amountStr.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(amountStr[i]);
    }
    return buffer.toString();
  }
}
