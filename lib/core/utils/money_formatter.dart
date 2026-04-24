import 'package:intl/intl.dart';

/// Whole naira amounts omit `.00`; fractional kobo shows two decimal places.
String formatMoney(double amount) {
  final kobo = (amount * 100).round();
  final whole = kobo ~/ 100;
  final frac = kobo.remainder(100).abs();
  const locale = 'en_US';
  if (frac == 0) {
    return NumberFormat('#,##0', locale).format(whole);
  }
  return NumberFormat('#,##0.00', locale).format(kobo / 100.0);
}
