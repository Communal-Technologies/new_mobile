import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists "show balance" per logged-in user. Extends [ChangeNotifier]
/// so every surface that shows the balance (home dashboard card, account
/// settings profile card, transaction history header) can listen and
/// stay in sync — toggling on one screen instantly updates the others
/// instead of waiting for a navigation-driven rebuild.
class HomeWalletPrefs extends ChangeNotifier {
  HomeWalletPrefs(this._prefs);

  final SharedPreferences _prefs;

  static String _key(String userId) =>
      'home_wallet_balance_visible_${userId.trim()}';

  /// Default visible when unset.
  bool isBalanceVisible(String userId) =>
      _prefs.getBool(_key(userId)) ?? true;

  Future<void> setBalanceVisible(String userId, bool visible) async {
    await _prefs.setBool(_key(userId), visible);
    notifyListeners();
  }
}
