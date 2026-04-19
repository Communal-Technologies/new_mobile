/// Utility class for formatting currency values
class CurrencyFormatter {
  /// Whole naira from API kobo (1 NGN = 100 kobo).
  static String formatNairaFromKobo(int kobo) {
    final naira = (kobo / 100).round();
    return formatNaira(naira);
  }

  /// Formats an integer amount as Nigerian Naira with commas
  /// Example: 5000000 -> "₦5,000,000"
  static String formatNaira(int amount) {
    final amountStr = amount.toString();
    final buffer = StringBuffer('₦');
    
    for (int i = 0; i < amountStr.length; i++) {
      if (i > 0 && (amountStr.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(amountStr[i]);
    }
    
    return buffer.toString();
  }
}

