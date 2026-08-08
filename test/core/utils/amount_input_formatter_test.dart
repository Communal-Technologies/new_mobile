import 'package:communal_mobile/core/utils/amount_input_formatter.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Simulates typing [input] one character at a time, which is how the
/// formatter actually runs on the field.
String typed(String input) {
  final formatter = AmountInputFormatter();
  var value = TextEditingValue.empty;
  for (final ch in input.split('')) {
    final next = TextEditingValue(
      text: value.text + ch,
      selection: TextSelection.collapsed(offset: value.text.length + 1),
    );
    value = formatter.formatEditUpdate(value, next);
  }
  return value.text;
}

void main() {
  // The bill amount fields now group thousands for display and then parse that
  // same grouped string back into kobo. If the two ever disagree the minimum
  // check reads a different number than the user typed, so pin the round trip.
  group('grouped bill amounts round-trip to kobo', () {
    test('whole and fractional values', () {
      expect(typed('5000'), '5,000');
      expect(Money.tryParseMajor(typed('5000'), 'NGN')!.amountMinor, 500000);
      expect(Money.tryParseMajor(typed('5000.50'), 'NGN')!.amountMinor, 500050);
      expect(
        Money.tryParseMajor(typed('1000000'), 'NGN')!.amountMinor,
        100000000,
      );
    });

    test('the electricity ₦100 minimum resolves either side of the bound', () {
      expect(Money.tryParseMajor(typed('99'), 'NGN')!.amountMinor < 10000, isTrue);
      expect(Money.tryParseMajor(typed('100'), 'NGN')!.amountMinor < 10000, isFalse);
    });
  });
}
