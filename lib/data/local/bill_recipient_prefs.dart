import 'package:shared_preferences/shared_preferences.dart';

import 'package:communal_mobile/core/utils/ng_mobile_network.dart';

/// The phone numbers one member recently bought airtime, data or a bill receipt
/// for, newest first, kept per account so a second member signing in on the same
/// device never sees the first one's numbers. The member's own number is not
/// stored: it is always offered first, so the list only holds the others.
class BillRecipientPrefs {
  BillRecipientPrefs(this._prefs, this._userId);

  final SharedPreferences _prefs;
  final String _userId;

  static const int keep = 3;

  static Future<BillRecipientPrefs> load(String userId) async =>
      BillRecipientPrefs(await SharedPreferences.getInstance(), userId);

  String get _key => 'bill_recent_phones:$_userId';

  List<String> recentPhones({String? ownPhone}) {
    if (_userId.isEmpty) return const [];
    final own = ownPhone == null ? '' : ngLocalPhone(ownPhone);
    return (_prefs.getStringList(_key) ?? const <String>[])
        .where((p) => p.isNotEmpty && p != own)
        .take(keep)
        .toList(growable: false);
  }

  Future<void> remember(String phone, {String? ownPhone}) async {
    if (_userId.isEmpty) return;
    final local = ngLocalPhone(phone);
    final own = ownPhone == null ? '' : ngLocalPhone(ownPhone);
    if (local.length != 11 || local == own) return;
    final next = [
      local,
      ...recentPhones(ownPhone: ownPhone).where((p) => p != local),
    ].take(keep).toList(growable: false);
    await _prefs.setStringList(_key, next);
  }
}
