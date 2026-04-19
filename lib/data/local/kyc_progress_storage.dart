import 'package:shared_preferences/shared_preferences.dart';

/// Persists Anchor customer id and in-app KYC wizard position per logged-in user
/// (mirrors legacy [KycProvider.anchorCustomerId] + resume behavior).
///
/// Step values:
/// - `0` — profile step not completed in this flow (or cleared).
/// - `1` — profile/register API succeeded; [anchorCustomerId] is set; resume at bank.
/// - `2` — bank step completed locally; resume at proof of identity.
/// - `3` — proof submitted locally; resume at verifying / later steps.
class KycProgressStorage {
  KycProgressStorage(this._prefs);

  final SharedPreferences _prefs;

  static String _anchorKey(String userId) => 'kyc_anchor_customer_id_$userId';
  static String _stepKey(String userId) => 'kyc_resume_step_$userId';

  /// Anchor customer id from `POST /compliance/register/{userId}` (`customer_id`).
  String? getAnchor(String userId) {
    final v = _prefs.getString(_anchorKey(userId));
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  /// See class doc. Defaults to `0`.
  int getResumeStep(String userId) => _prefs.getInt(_stepKey(userId)) ?? 0;

  /// Call after successful profile registration; stores id and sets resume to bank (step 1).
  Future<void> saveAfterProfileRegistered(
    String userId,
    String anchorCustomerId,
  ) async {
    final id = anchorCustomerId.trim();
    if (id.isEmpty) return;
    await _prefs.setString(_anchorKey(userId), id);
    await _prefs.setInt(_stepKey(userId), 1);
  }

  /// After user finishes bank step (continue or skip toward proof).
  Future<void> markBankStepDone(String userId) async {
    await _prefs.setInt(_stepKey(userId), 2);
  }

  /// After user submits proof-of-identity form (before verifying screen).
  Future<void> markProofStepDone(String userId) async {
    await _prefs.setInt(_stepKey(userId), 3);
  }

  /// When KYC flow is finished (e.g. reached dashboard from All Set).
  Future<void> clear(String userId) async {
    await _prefs.remove(_anchorKey(userId));
    await _prefs.remove(_stepKey(userId));
  }

  /// Ensures anchor is on disk when we only received it via navigation [extra].
  Future<void> ensureAnchorSynced(
    String userId,
    String anchorCustomerId, {
    required int minResumeStep,
  }) async {
    final id = anchorCustomerId.trim();
    if (id.isEmpty) return;
    final existing = getAnchor(userId);
    if (existing != id) {
      await _prefs.setString(_anchorKey(userId), id);
    }
    final step = getResumeStep(userId);
    if (step < minResumeStep) {
      await _prefs.setInt(_stepKey(userId), minResumeStep);
    }
  }
}
