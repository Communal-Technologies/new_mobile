import 'package:flutter/services.dart';

/// Formats a money amount field as the user types: thousands separators on the
/// integer part, an optional single decimal point, and at most [decimals]
/// fractional digits (so a user can enter e.g. `550.50`).
///
/// Pair with `Money.tryParseMajor` (which strips the commas) to get minor units.
class AmountInputFormatter extends TextInputFormatter {
  AmountInputFormatter({this.decimals = 2});

  final int decimals;

  static String _group(String intDigits) {
    if (intDigits.isEmpty) return '';
    final chars = intDigits.split('').reversed.toList();
    final out = <String>[];
    for (var i = 0; i < chars.length; i++) {
      out.add(chars[i]);
      if ((i + 1) % 3 == 0 && i != chars.length - 1) out.add(',');
    }
    return out.reversed.join();
  }

  /// Formats a whole-number value with thousands separators (no decimals) —
  /// used by the quick-amount chips.
  static String formatInt(int value) => _group(value.toString());

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Keep only digits and dots; collapse to a single decimal point.
    var text = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final dot = text.indexOf('.');
    String intPart;
    String fracPart;
    var hasDot = false;
    if (dot == -1) {
      intPart = text;
      fracPart = '';
    } else {
      hasDot = true;
      intPart = text.substring(0, dot);
      // Drop any further dots in the fractional segment, cap to [decimals].
      fracPart = text.substring(dot + 1).replaceAll('.', '');
      if (fracPart.length > decimals) fracPart = fracPart.substring(0, decimals);
      if (decimals == 0) {
        hasDot = false;
        fracPart = '';
      }
    }

    final intDigits = intPart.replaceAll(RegExp(r'[^0-9]'), '');
    // Strip leading zeros but keep a single leading zero (e.g. "0.50").
    final normalizedInt = intDigits.replaceAll(RegExp(r'^0+(?=\d)'), '');
    final grouped = _group(normalizedInt);

    var out = grouped;
    if (hasDot) {
      out = '${grouped.isEmpty ? '0' : grouped}.$fracPart';
    }

    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}
