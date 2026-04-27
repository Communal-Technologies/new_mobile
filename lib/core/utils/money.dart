import 'package:intl/intl.dart';

import 'app_currency.dart';

/// Number of decimal places ISO 4217 (and a few crypto codes) expose at
/// display time. Anything not listed falls back to 2 (the common case).
const Map<String, int> kCurrencyDecimals = <String, int>{
  // Zero-decimal
  'BIF': 0, 'CLP': 0, 'DJF': 0, 'GNF': 0, 'JPY': 0, 'KMF': 0, 'KRW': 0,
  'MGA': 0, 'PYG': 0, 'RWF': 0, 'UGX': 0, 'VND': 0, 'VUV': 0,
  'XAF': 0, 'XOF': 0, 'XPF': 0,

  // Two-decimal
  'AUD': 2, 'BRL': 2, 'CAD': 2, 'CHF': 2, 'CNY': 2, 'EGP': 2, 'EUR': 2,
  'GBP': 2, 'GHS': 2, 'HKD': 2, 'INR': 2, 'KES': 2, 'NGN': 2, 'NZD': 2,
  'PLN': 2, 'RUB': 2, 'SGD': 2, 'TRY': 2, 'USD': 2, 'ZAR': 2,

  // Three-decimal
  'BHD': 3, 'IQD': 3, 'JOD': 3, 'KWD': 3, 'LYD': 3, 'OMR': 3, 'TND': 3,

  // Crypto
  'BTC': 8, 'ETH': 18,
};

/// Number of decimals for [currency]. Falls back to 2 for unknown codes.
int decimalsFor(String currency) {
  final code = currency.trim().toUpperCase();
  return kCurrencyDecimals[code] ?? 2;
}

/// Multiplier between major units (NGN, USD…) and minor units (kobo, cents…).
int factorFor(String currency) {
  var factor = 1;
  for (var i = 0; i < decimalsFor(currency); i++) {
    factor *= 10;
  }
  return factor;
}

/// Immutable money value object.
///
/// `amountMinor` is an integer count of the smallest unit of `currency`
/// (e.g. kobo for NGN, cents for USD). All arithmetic happens on integers;
/// double-precision floats never enter the path.
class Money {
  final int amountMinor;
  final String currency;

  Money(this.amountMinor, String currency)
      : currency = currency.trim().toUpperCase() {
    if (this.currency.length != 3) {
      throw ArgumentError(
        'currency must be an ISO 4217 alpha-3 code, got: $currency',
      );
    }
  }

  /// Build from a major-unit display value ("12.50"). Rounds half-away-from-zero.
  factory Money.fromMajor(num amountMajor, String currency) {
    final minor = (amountMajor * factorFor(currency)).round();
    return Money(minor, currency);
  }

  /// Parse a user-typed major-unit string ("1,234.56") into a Money value.
  /// Returns null when the input is empty or not numeric.
  static Money? tryParseMajor(String text, String currency) {
    final cleaned = text.replaceAll(RegExp(r'[,\s ]'), '').trim();
    if (cleaned.isEmpty) return null;
    final n = num.tryParse(cleaned);
    if (n == null) return null;
    final minor = (n * factorFor(currency)).round();
    return Money(minor, currency);
  }

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money(amountMinor + other.amountMinor, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money(amountMinor - other.amountMinor, currency);
  }

  bool get isZero => amountMinor == 0;
  bool get isNegative => amountMinor < 0;

  /// Major-unit string with the right number of decimals, no thousands separator.
  ///   Money(2500, 'NGN').toMajorString()  // "25.00"
  ///   Money(1500, 'JPY').toMajorString()  // "1500"
  ///   Money(12345, 'BHD').toMajorString() // "12.345"
  String toMajorString() {
    final decimals = decimalsFor(currency);
    if (decimals == 0) return amountMinor.toString();
    final factor = factorFor(currency);
    final negative = amountMinor < 0;
    final abs = amountMinor.abs();
    final whole = abs ~/ factor;
    final frac = abs - whole * factor;
    return '${negative ? '-' : ''}$whole.${frac.toString().padLeft(decimals, '0')}';
  }

  /// Localized display string with thousands separators and the currency symbol.
  ///   Money(2500000, 'NGN').format()  // "₦25,000.00"
  ///   Money(1500, 'JPY').format()     // "¥1,500"
  String format({bool symbol = true, String locale = 'en_US'}) {
    final decimals = decimalsFor(currency);
    final pattern = decimals == 0 ? '#,##0' : '#,##0.${'0' * decimals}';
    final factor = factorFor(currency);
    final value = amountMinor / factor;
    final formatted = NumberFormat(pattern, locale).format(value);
    if (!symbol) return formatted;
    final sym = currencySymbolForCode(currency);
    final needsSpace = RegExp(r'^[A-Za-z]+').hasMatch(sym);
    return '$sym${needsSpace ? ' ' : ''}$formatted';
  }

  Map<String, Object> toJson() => <String, Object>{
        'amount_minor': amountMinor,
        'currency': currency,
      };

  @override
  String toString() => format();

  void _assertSameCurrency(Money other) {
    if (currency != other.currency) {
      throw ArgumentError(
        'Currency mismatch: $currency vs ${other.currency}',
      );
    }
  }
}
