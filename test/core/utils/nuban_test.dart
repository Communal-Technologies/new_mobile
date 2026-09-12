import 'package:communal_mobile/core/utils/nuban.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nubanCheckDigit', () {
    test('matches the CBN weighting for known pairs', () {
      expect(nubanCheckDigit('011', '000001457'), 9);
      expect(nubanCheckDigit('058', '012345678'), 5);
      expect(nubanCheckDigit('044', '100000000'), 7);
      expect(nubanCheckDigit('999', '999999999'), 2);
      expect(nubanCheckDigit('000', '000000000'), 0);
    });

    test('rejects inputs of the wrong shape', () {
      expect(nubanCheckDigit('11', '000001457'), isNull);
      expect(nubanCheckDigit('0011', '000001457'), isNull);
      expect(nubanCheckDigit('01A', '000001457'), isNull);
      expect(nubanCheckDigit('011', '00000145'), isNull);
      expect(nubanCheckDigit('011', '00000145X'), isNull);
    });
  });

  group('nubanMatchesBank', () {
    test('accepts the bank that could have issued the number', () {
      expect(nubanMatchesBank('0123456785', '058'), isTrue);
    });

    test('rejects a bank whose code produces a different check digit', () {
      expect(nubanMatchesBank('0123456785', '011'), isFalse);
    });

    test('accepts anything it cannot check', () {
      expect(nubanMatchesBank('012345', '058'), isTrue);
      expect(nubanMatchesBank('08012345678', '999'), isTrue);
      expect(nubanMatchesBank('0123456785', '0058'), isTrue);
      expect(nubanMatchesBank('012345678A', '058'), isTrue);
    });
  });

  group('banksMatchingNuban', () {
    final codes = List.generate(1000, (i) => i.toString().padLeft(3, '0'));

    test('narrows a full registry to roughly a tenth', () {
      final matches = banksMatchingNuban('0123456785', codes);
      expect(matches, contains('058'));
      expect(matches.length, lessThan(codes.length ~/ 5));
      expect(matches.length, greaterThan(0));
    });

    test('leaves a number it cannot check untouched', () {
      expect(banksMatchingNuban('01234', codes).length, codes.length);
      expect(banksMatchingNuban('08012345678', codes).length, codes.length);
    });

    test('falls back to the full list when nothing matches', () {
      final matches = banksMatchingNuban('0123456785', ['011', '044']);
      expect(matches, ['011', '044']);
    });
  });

  test('isNubanShaped only accepts ten digits', () {
    expect(isNubanShaped('0123456789'), isTrue);
    expect(isNubanShaped('012345678'), isFalse);
    expect(isNubanShaped('01234567890'), isFalse);
    expect(isNubanShaped('01234 6789'), isFalse);
    expect(isNubanShaped(''), isFalse);
  });
}
