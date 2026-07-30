import 'package:intl_phone_number_input/intl_phone_number_input.dart';

/// Formats phone numbers for the API: Nigerian accounts use local `0XXXXXXXXXX`;
/// other regions use E.164 (`+` country code + national digits).
///
/// **Nigeria:** Existing users and the backend store Nigerian mobiles as **11 digits with a
/// leading `0`** (e.g. `08031234567`). [apiLoginFromPhoneNumber] always normalizes NG input
/// to that shape when possible so login/OTP matches [users.phone] and
/// `NigerianPhoneNumber` on the server.
abstract final class PhoneLoginFormat {
  static String _digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

  /// Login / phone string for auth and OTP endpoints.
  static String apiLoginFromPhoneNumber(PhoneNumber phone) {
    final iso = phone.isoCode?.toUpperCase() ?? '';
    if (iso == 'NG') {
      final local = _tryNigerianLocalDigits(phone.phoneNumber);
      if (local != null) return local;
    }
    return _toE164(phone);
  }

  /// Resolves to the backend’s Nigerian local format (`0` + 10 further digits).
  static String? _tryNigerianLocalDigits(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final d = _digitsOnly(raw);
    // Already stored / entered as local: `08031234567` → send unchanged.
    if (d.length == 11 && d.startsWith('0')) return d;
    if (d.startsWith('234')) {
      final nsn = d.substring(3);
      if (nsn.length == 10) {
        final c = nsn[0];
        if ('789'.contains(c)) return '0$nsn';
      }
      if (nsn.length == 11 && nsn.startsWith('0')) return nsn;
    }
    if (d.length == 10 && d.isNotEmpty && '789'.contains(d[0])) {
      return '0$d';
    }
    return null;
  }

  static String _toE164(PhoneNumber p) {
    var raw = (p.phoneNumber ?? '').trim();
    if (raw.startsWith('+')) {
      return raw.replaceAll(RegExp(r'\s'), '');
    }
    final dc = (p.dialCode ?? '').replaceAll(RegExp(r'\D'), '');
    final all = _digitsOnly(raw);
    if (dc.isNotEmpty && all.startsWith(dc)) return '+$all';
    if (all.isNotEmpty) return '+$dc$all';
    return '+$dc';
  }

  /// Best-effort [PhoneNumber] for prefilling the phone widget from a stored login.
  static Future<PhoneNumber> phoneNumberForPrefill(
    String contact,
    List<String> allowedCountryIsos,
  ) async {
    final t = contact.trim();
    if (t.contains('@')) {
      final iso = allowedCountryIsos.isNotEmpty
          ? allowedCountryIsos.first.toUpperCase()
          : 'NG';
      return PhoneNumber(isoCode: iso);
    }
    if (t.startsWith('+') || t.startsWith('00')) {
      final normalized = t.startsWith('00') ? '+${t.substring(2)}' : t;
      try {
        final pn = await PhoneNumber.getRegionInfoFromPhoneNumber(
          normalized.replaceAll(' ', ''),
          '',
        );
        if (pn.isoCode != null &&
            allowedCountryIsos
                .map((e) => e.toUpperCase())
                .contains(pn.isoCode!.toUpperCase())) {
          return pn;
        }
      } catch (_) {}
    }
    final d = _digitsOnly(t);
    final upper = allowedCountryIsos.map((e) => e.toUpperCase()).toList();
    if (upper.contains('NG')) {
      var national = d;
      if (national.startsWith('234')) national = national.substring(3);
      if (national.length == 10) national = '0$national';
      if (national.length == 11 && national.startsWith('0')) {
        return PhoneNumber(
          phoneNumber: national,
          dialCode: '+234',
          isoCode: 'NG',
        );
      }
    }
    final iso = upper.isNotEmpty ? upper.first : 'NG';
    return PhoneNumber(isoCode: iso);
  }
}
