import 'package:intl/intl.dart';

import 'money.dart';

/// Legacy helper: format a `double` amount in major units (e.g. naira) with
/// thousands separators, omitting `.00` on whole amounts. Defaults to NGN to
/// match the original single-arg signature; pass [currency] to format another
/// currency.
///
/// Prefer [Money.format] or [formatMinor] in new code — those operate on
/// integer minor units and always show the right number of decimals.
String formatMoney(double amount, [String currency = 'NGN']) {
  final decimals = decimalsFor(currency);
  final factor = factorFor(currency);
  final minor = (amount * factor).round();
  final whole = minor ~/ factor;
  final frac = minor.remainder(factor).abs();
  const locale = 'en_US';
  if (frac == 0 || decimals == 0) {
    return NumberFormat('#,##0', locale).format(whole);
  }
  final pattern = '#,##0.${'0' * decimals}';
  return NumberFormat(pattern, locale).format(minor / factor);
}

/// Format a known integer-minor amount with no symbol, always showing the
/// canonical number of decimals for [currency]. Use this from new code.
///   formatMinor(2_500_00, 'NGN') // "2,500.00"
///   formatMinor(1500, 'JPY')     // "1,500"
String formatMinor(int amountMinor, String currency) =>
    Money(amountMinor, currency).format(symbol: false);
