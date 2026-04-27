import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight wrapper over the two user-facing biometric toggles surfaced
/// in [BiometricEnrollmentScreen]. The master enrollment state lives in
/// [BiometricSignerService] / the backend; these prefs control where the
/// enrolled biometric is actually *used*:
///
/// - [appLoginEnabled]      — whether the welcome-back screen auto-prompts
///                            biometric for unlock. Independent local pref.
/// - [transactionsEnabled]  — whether the transfer / obligation flows
///                            attempt to sign with biometric. When `false`
///                            the screens block the transaction with a
///                            "biometric required" error pointing the user
///                            back to Settings (the audit M38 backend gate
///                            still enforces; bypassing the prompt
///                            client-side without re-enrolling means the
///                            server returns 403). Independent local pref.
///
/// Defaults: both `true` so a fresh enrollment immediately benefits from
/// both biometric paths. The toggles stay editable independently.
class BiometricPrefs {
  BiometricPrefs(this._prefs);

  final SharedPreferences _prefs;

  static const String _kAppLogin = 'biometric_app_login_enabled';
  static const String _kTransactions = 'biometric_transactions_enabled';

  bool get appLoginEnabled => _prefs.getBool(_kAppLogin) ?? true;
  bool get transactionsEnabled => _prefs.getBool(_kTransactions) ?? true;

  Future<void> setAppLoginEnabled(bool value) =>
      _prefs.setBool(_kAppLogin, value);

  Future<void> setTransactionsEnabled(bool value) =>
      _prefs.setBool(_kTransactions, value);

  /// Reset both flags. Called on master-toggle off (via unenrollment) so
  /// the next time the user re-enrolls, the granular flags don't carry
  /// stale state.
  Future<void> resetAll() async {
    await _prefs.remove(_kAppLogin);
    await _prefs.remove(_kTransactions);
  }
}
