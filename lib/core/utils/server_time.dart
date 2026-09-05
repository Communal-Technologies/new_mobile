/// Timestamp parsing for values that come from the platform's APIs.
///
/// Every Communal backend runs on UTC — the server's clock is UTC, Laravel's
/// `app.timezone` is `UTC`, and the Go services bind UTC — so every timestamp on
/// the wire is UTC no matter which service produced it. The device is not: a
/// member in Lagos is on WAT, UTC+1.
///
/// Two shapes arrive, and left to `DateTime.parse` both render an hour behind:
///
///  * **no zone designator** (`2026-09-05 18:25:00`, which is what a raw SQL
///    select returns) — `DateTime.parse` reads it as *device-local* wall clock, so
///    a 19:25 event is claimed to have happened at 18:25;
///  * **`Z`-suffixed or offset ISO** (`2026-09-05T18:25:00.000000Z`, Eloquent and
///    Go's RFC3339) — that parses to a correct instant, but it is a *UTC*
///    `DateTime`, and `DateFormat` prints the fields the object holds without
///    converting, so 18:25 is what the member sees.
///
/// So the fix is both halves: assume UTC when nothing says otherwise, and always
/// hand back a local `DateTime` so anything that formats it is already right.
///
/// A **date-only** value (`2026-09-05` — a date of birth, a due date) is left as a
/// plain local date. It names a calendar day, not an instant; pushing it through UTC
/// would move it to the day before for anyone west of Greenwich.
library;

final RegExp _hasTimeOfDay = RegExp(r'[T ]\d{1,2}:\d{2}');
final RegExp _hasZoneDesignator = RegExp(r'([zZ]|[+-]\d{2}:?\d{2})$');

/// Microsecond precision is Dart's limit; Anchor and some SQL Server-backed
/// providers send seven or more fractional digits, which `DateTime.parse` rejects
/// outright rather than truncating.
final RegExp _overlongFraction = RegExp(r'^(.*?)\.(\d{7,})([zZ]|[+-]\d{2}:?\d{2})?$');

/// Parses a server timestamp and returns it in the device's own zone.
///
/// Accepts anything the API layer hands over — a `String`, an already-parsed
/// `DateTime`, or `null` — and returns `null` when there is nothing usable, so it
/// drops straight into the `?? DateTime.now()` and `?? fallback` shapes the models
/// already use.
DateTime? parseServerTime(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toLocal();

  var s = raw.toString().trim();
  if (s.isEmpty) return null;

  final overlong = _overlongFraction.firstMatch(s);
  if (overlong != null) {
    s = '${overlong[1]}.${overlong[2]!.substring(0, 6)}${overlong[3] ?? ''}';
  }

  if (_hasTimeOfDay.hasMatch(s) && !_hasZoneDesignator.hasMatch(s)) {
    s = '${s}Z';
  }

  return DateTime.tryParse(s)?.toLocal();
}

final RegExp _leadingCalendarDate = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})');

/// Parses a field that names a **calendar day** rather than an instant — a date of
/// birth, a due date, a maturity date — and returns it as local midnight.
///
/// These need the opposite treatment to [parseServerTime]: no zone arithmetic at
/// all. Eloquent serialises a `date` cast as `1990-04-17T00:00:00.000000Z`, and
/// converting that to the zone of a member sitting in New York would show them the
/// 16th. A due date is the same day in every zone, so the digits the server sent are
/// the answer.
DateTime? parseServerDate(Object? raw) {
  if (raw == null) return null;
  if (raw is DateTime) return DateTime(raw.year, raw.month, raw.day);

  final s = raw.toString().trim();
  if (s.isEmpty) return null;

  final m = _leadingCalendarDate.firstMatch(s);
  if (m != null) {
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  final parsed = DateTime.tryParse(s);
  return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
}
