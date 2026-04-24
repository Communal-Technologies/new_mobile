import 'package:shared_preferences/shared_preferences.dart';

/// Persists home wallet “show balance” per logged-in user (survives navigation).
class HomeWalletPrefs {
  HomeWalletPrefs(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String userId) =>
      'home_wallet_balance_visible_${userId.trim()}';

  /// Default visible when unset.
  bool isBalanceVisible(String userId) =>
      _prefs.getBool(_key(userId)) ?? true;

  Future<void> setBalanceVisible(String userId, bool visible) async {
    await _prefs.setBool(_key(userId), visible);
  }
}
