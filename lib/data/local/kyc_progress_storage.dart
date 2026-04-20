import 'package:shared_preferences/shared_preferences.dart';

/// Persists Anchor customer id and in-app KYC wizard position per logged-in user
/// (mirrors legacy [KycProvider.anchorCustomerId] + resume behavior).
///
/// Step values:
/// - `0` — profile step not completed in this flow (or cleared).
/// - `1` — profile/register API succeeded; [anchorCustomerId] is set; resume at bank.
/// - `2` — bank tier-1 (BVN) **submitted successfully** via API; resume at proof of identity.
///   Skipping bank does **not** set this — only a successful Continue on the bank screen.
/// - `3` — proof submitted locally; resume at verifying / later steps.
///
/// [KycResumeDestination] is derived from the **first incomplete** step (not “last visited”).
enum KycResumeDestination {
  profile,
  bank,
  proof,
  verifying,
}

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

  /// Where to open the KYC flow: first **incomplete** step, using [communalTier] when present
  /// (`tier_0` ⇒ bank not done; `tier_1` / `tier_2` ⇒ bank done) and local [getResumeStep] for proof.
  KycResumeDestination resumeDestination(
    String userId, {
    String? communalTier,
  }) {
    final anchor = getAnchor(userId);
    if (anchor == null || anchor.isEmpty) {
      return KycResumeDestination.profile;
    }
    final step = getResumeStep(userId);
    if (!_bankTierComplete(communalTier, step)) {
      return KycResumeDestination.bank;
    }
    if (!_proofComplete(step)) {
      return KycResumeDestination.proof;
    }
    return KycResumeDestination.verifying;
  }

  static bool _bankTierComplete(String? communalTier, int resumeStep) {
    final t = communalTier?.trim().toLowerCase();
    if (t == 'tier_1' || t == 'tier_2') return true;
    if (t == 'tier_0') return false;
    return resumeStep >= 2;
  }

  static bool _proofComplete(int resumeStep) => resumeStep >= 3;

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

  /// After tier-1 BVN upgrade succeeds (Continue on bank screen). Not used when user skips bank.
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

  /// Persists [anchorCustomerId] when it arrives via navigation [extra] only.
  ///
  /// Does **not** change the resume step — that must only move via
  /// [saveAfterProfileRegistered], [markBankStepDone], or [markProofStepDone].
  /// (Previously bumping step here caused users who never finished bank to be
  /// sent to proof or verifying on the next launch.)
  Future<void> ensureAnchorSynced(String userId, String anchorCustomerId) async {
    final id = anchorCustomerId.trim();
    if (id.isEmpty) return;
    final existing = getAnchor(userId);
    if (existing != id) {
      await _prefs.setString(_anchorKey(userId), id);
    }
  }
}
