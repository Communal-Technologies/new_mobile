/// Utility class for formatting currency values
class CurrencyFormatter {
  /// Whole naira from API kobo (1 NGN = 100 kobo).
  static String formatNairaFromKobo(int kobo) {
    final naira = (kobo / 100).round();
    return formatNaira(naira);
  }

  /// Kobo → naira with **two** fractional digits (e.g. `0` → `₦0.00`).
  static String formatNairaFromKoboWithDecimals(int kobo) {
    final negative = kobo < 0;
    final abs = kobo.abs();
    final whole = abs ~/ 100;
    final cents = abs % 100;
    final buf = StringBuffer('₦');
    if (negative) buf.write('-');
    buf.write(_digitsWithThousandsSeparators(whole));
    buf.write('.');
    buf.write(cents.toString().padLeft(2, '0'));
    return buf.toString();
  }

  /// Formats an integer amount as Nigerian Naira with commas
  /// Example: 5000000 -> "₦5,000,000"
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
