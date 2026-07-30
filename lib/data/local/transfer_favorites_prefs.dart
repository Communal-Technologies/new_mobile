import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class TransferFavorite {
  const TransferFavorite({
    required this.source,
    required this.accountId,
    required this.bank,
    required this.accountNumber,
    required this.accountName,
    this.nipCode,
  });

  final String source; // internal | external
  final String accountId;
  final String bank;
  final String accountNumber;
  final String accountName;
  final String? nipCode;

  bool get isInternal => source.trim().toLowerCase() == 'internal';

  Map<String, dynamic> toJson() => {
    'source': source,
    'account_id': accountId,
    'bank': bank,
    'accountNumber': accountNumber,
    'accountName': accountName,
    'nipCode': nipCode,
  };

  factory TransferFavorite.fromJson(Map<String, dynamic> json) {
    return TransferFavorite(
      source: json['source']?.toString() ?? '',
      accountId: json['account_id']?.toString() ?? '',
      bank: json['bank']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      nipCode: json['nipCode']?.toString(),
    );
  }
}

class TransferFavoritesPrefs {
  TransferFavoritesPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const String _key = 'transfer_favorites_v1';

  List<TransferFavorite> getAll() {
    final raw = _prefs.getStringList(_key) ?? const <String>[];
    final out = <TransferFavorite>[];
    for (final item in raw) {
      try {
        final map = jsonDecode(item);
        if (map is Map) {
          out.add(TransferFavorite.fromJson(Map<String, dynamic>.from(map)));
        }
      } catch (_) {}
    }
    return out;
  }

  Future<void> upsert(TransferFavorite fav) async {
    final existing = getAll();
    final key = '${fav.source}|${fav.accountId}|${fav.accountNumber}';
    final deduped = existing
        .where((e) => '${e.source}|${e.accountId}|${e.accountNumber}' != key)
        .toList();
    deduped.insert(0, fav);
    final capped = deduped.take(30).toList(growable: false);
    final raw = capped.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs.setStringList(_key, raw);
  }

  Future<void> remove(TransferFavorite fav) async {
    final existing = getAll();
    final key = '${fav.source}|${fav.accountId}|${fav.accountNumber}';
    final deduped = existing
        .where((e) => '${e.source}|${e.accountId}|${e.accountNumber}' != key)
        .toList(growable: false);
    final raw = deduped.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs.setStringList(_key, raw);
  }
}
