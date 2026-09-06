import 'package:communal_mobile/core/utils/server_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseServerTime', () {
    test('reads a zone-less timestamp as UTC and returns it local', () {
      final dt = parseServerTime('2026-09-05 18:25:00')!;
      expect(dt.isUtc, isFalse);
      expect(dt.toUtc(), DateTime.utc(2026, 9, 5, 18, 25));
    });

    test('keeps the instant of a Z-suffixed timestamp but hands back local', () {
      final dt = parseServerTime('2026-09-05T18:25:00.000000Z')!;
      expect(dt.isUtc, isFalse);
      expect(dt.toUtc(), DateTime.utc(2026, 9, 5, 18, 25));
    });

    test('honours an explicit offset rather than overriding it', () {
      final dt = parseServerTime('2026-09-05T19:25:00+01:00')!;
      expect(dt.toUtc(), DateTime.utc(2026, 9, 5, 18, 25));
    });

    test('leaves a date-only value on its calendar day', () {
      final dt = parseServerTime('1990-04-17')!;
      expect(dt.isUtc, isFalse);
      expect(dt.year, 1990);
      expect(dt.month, 4);
      expect(dt.day, 17);
    });

    test('truncates an over-precise provider fraction instead of failing', () {
      final dt = parseServerTime('2026-09-05T18:25:00.1234567Z')!;
      expect(dt.toUtc().millisecondsSinceEpoch,
          DateTime.utc(2026, 9, 5, 18, 25, 0, 123).millisecondsSinceEpoch);
    });

    test('truncates an over-precise fraction with no designator too', () {
      final dt = parseServerTime('2026-09-05T18:25:00.1234567')!;
      expect(dt.toUtc(), DateTime.utc(2026, 9, 5, 18, 25, 0, 123, 456));
    });

    test('returns null for nothing usable', () {
      expect(parseServerTime(null), isNull);
      expect(parseServerTime(''), isNull);
      expect(parseServerTime('   '), isNull);
      expect(parseServerTime('not a date'), isNull);
    });

    test('localises a DateTime that has already been parsed as UTC', () {
      final dt = parseServerTime(DateTime.utc(2026, 9, 5, 18, 25))!;
      expect(dt.isUtc, isFalse);
      expect(dt.toUtc(), DateTime.utc(2026, 9, 5, 18, 25));
    });

    test('the reported case: a 19:25 WAT transaction does not read 18:25', () {
      // The wire value for a transaction a member made at 7:25pm in Lagos.
      final dt = parseServerTime('2026-09-05 18:25:00')!;
      final wat = dt.toUtc().add(const Duration(hours: 1));
      expect(wat.hour, 19);
      expect(wat.minute, 25);
    });
  });

  group('parseServerDate', () {
    test('keeps a midnight-UTC date cast on its own calendar day', () {
      final d = parseServerDate('1990-04-17T00:00:00.000000Z')!;
      expect(d, DateTime(1990, 4, 17));
    });

    test('reads a bare date', () {
      expect(parseServerDate('2026-10-05'), DateTime(2026, 10, 5));
    });

    test('drops the time from a full timestamp', () {
      expect(parseServerDate('2026-10-05 23:45:00'), DateTime(2026, 10, 5));
    });

    test('returns null for nothing usable', () {
      expect(parseServerDate(null), isNull);
      expect(parseServerDate(''), isNull);
      expect(parseServerDate('not a date'), isNull);
    });

    test('never returns a UTC DateTime, so DateFormat prints the right day', () {
      final d = parseServerDate('2026-10-05T00:00:00Z')!;
      expect(d.isUtc, isFalse);
      expect(d.day, 5);
    });
  });

}
