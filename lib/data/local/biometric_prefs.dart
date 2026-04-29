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
  // user_id of the account that enrolled biometric on this device. Without
  // this, enrollment leaks across users — User A enrols, logs out, User B
  // logs in on the same device, and User B's idle-lock screen would auto-
  // prompt biometric (the local key + appLogin pref are device-scoped).
  // Welcome-back checks this against the *current* user before treating
  // biometric as enrolled.
  static const String _kEnrolledUserId = 'biometric_enrolled_user_id';

  bool get appLoginEnabled => _prefs.getBool(_kAppLogin) ?? true;
  bool get transactionsEnabled => _prefs.getBool(_kTransactions) ?? true;

  /// Account that owns the local enrollment, or null when nothing is
  /// enrolled (or pre-upgrade install where the field wasn't written).
  String? get enrolledUserId => _prefs.getString(_kEnrolledUserId);

  Future<void> setAppLoginEnabled(bool value) =>
      _prefs.setBool(_kAppLogin, value);

  Future<void> setTransactionsEnabled(bool value) =>
      _prefs.setBool(_kTransactions, value);

  Future<void> setEnrolledUserId(String userId) =>
      _prefs.setString(_kEnrolledUserId, userId);

  /// Reset all flags. Called on master-toggle off (via unenrollment) and
  /// on logout so the next user starts from a clean slate and can't be
  /// auto-prompted with a previous owner's enrollment.
  Future<void> resetAll() async {
    await _prefs.remove(_kAppLogin);
    await _prefs.remove(_kTransactions);
    await _prefs.remove(_kEnrolledUserId);
  }
}
