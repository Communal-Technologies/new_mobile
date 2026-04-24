import 'package:equatable/equatable.dart';
import 'package:communal_mobile/data/models/tier_limits_model.dart';

class UserModel extends Equatable {
  final String id;
  /// Best-effort display name (full name from profile, else username).
  final String name;
  final String login;
  final String? avatar;
  final bool hasSecurityPin;
  /// Raw API role, e.g. `member`.
  final String role;
  final String? cooperativeId;
  /// From `profile.cooperative.cooperative_name` when `get-loggedin-user` eager-loads cooperative.
  final String? cooperativeName;
  /// From `profile.cooperative.logo_url` when present (absolute URL).
  final String? cooperativeLogoUrl;
  final String? ledgerNumber;

  /// Profile / account fields for KYC prefill (when present on `get-loggedin-user`).
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? email;
  final String? phone;
  /// Profile `country` when stored as a 2-letter ISO code (e.g. NG).
  final String? countryIso;

  /// From `profile.tier` on `get-loggedin-user` (e.g. tier_0, tier_1, tier_2).
  final String? communalTier;
  /// From `profile.kyc` webhook-driven verification status (e.g. approved, pending_review, rejected).
  final String? kycStatus;
  /// From top-level `kyc.status` workflow state (e.g. tier2_submitted, awaitingDocument).
  final String? kycWorkflowStatus;

  /// From top-level `kyc.anchor_customer_id` on `get-loggedin-user`.
  final String? kycAnchorCustomerId;
  /// From top-level `kyc_progress.step_1_submitted`.
  final bool kycStep1Submitted;
  /// From top-level `kyc_progress.step_2_submitted`.
  final bool kycStep2Submitted;
  /// From top-level `kyc_progress.step_3_submitted`.
  final bool kycStep3Submitted;

  /// Member KYC tier limits + catalog from `tier_limits` on `get-loggedin-user`.
  final TierLimitsSnapshot? tierLimits;

  /// Wallet `account_balance` from `user.wallet` when eager-loaded (kobo).
  final int walletBalanceKobo;

  /// Wallet `account_number` (bank / virtual pay-in). Distinct from [ledgerNumber] on profile.
  final String? walletAccountNumber;

  /// Wallet `account_name` or `deposit_account_name` when present.
  final String? walletAccountName;

  /// Wallet `account_status`: `1` = active, `2` = frozen (see backend `Wallet`).
  final String? walletAccountStatus;

  /// Wallet `frozen_by`: member user id when self-frozen; otherwise admin/system id.
  final String? walletFrozenBy;

  const UserModel({
    required this.id,
    required this.name,
    required this.login,
    this.avatar,
    this.hasSecurityPin = false,
    this.role = 'member',
    this.cooperativeId,
    this.cooperativeName,
    this.cooperativeLogoUrl,
    this.ledgerNumber,
    this.firstName,
    this.middleName,
    this.lastName,
    this.email,
    this.phone,
    this.countryIso,
    this.communalTier,
    this.kycStatus,
    this.kycWorkflowStatus,
    this.kycAnchorCustomerId,
    this.kycStep1Submitted = false,
    this.kycStep2Submitted = false,
    this.kycStep3Submitted = false,
    this.tierLimits,
    this.walletBalanceKobo = 0,
    this.walletAccountNumber,
    this.walletAccountName,
    this.walletAccountStatus,
    this.walletFrozenBy,
  });

  String get roleLabel {
    if (role.isEmpty) return 'Member';
    return role[0].toUpperCase() + role.substring(1).toLowerCase();
  }

  /// Cooperative label for headers (prefer legal/display name over `cooperative_id`).
  String get cooperativeDisplayName {
    final n = cooperativeName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final id = cooperativeId?.trim();
    if (id != null && id.isNotEmpty) return id;
    return '—';
  }

  /// True when the profile is linked to a cooperative (id and/or name from API).
  bool get hasCooperativeMembership {
    final id = cooperativeId?.trim();
    final n = cooperativeName?.trim();
    return (id != null && id.isNotEmpty) || (n != null && n.isNotEmpty);
  }

  /// Wallet is frozen (`account_status` = 2).
  bool get isWalletFrozen {
    final s = walletAccountStatus?.trim();
    if (s == null || s.isEmpty) return false;
    return s == '2';
  }

  /// Frozen by the logged-in member (self-freeze). Admin/other freezes use another `frozen_by`.
  bool get isWalletSelfFrozen {
    if (!isWalletFrozen) return false;
    final fb = walletFrozenBy?.trim();
    final uid = id.trim();
    if (fb == null || fb.isEmpty || uid.isEmpty) return false;
    return fb == uid;
  }

  /// True when a bank / virtual pay-in account number exists on the wallet.
  bool get hasProvisionedWalletAccountNumber {
    final n = walletAccountNumber?.trim();
    return n != null && n.isNotEmpty;
  }

  /// Home banner: Communal tier is already Tier 1+ (e.g. BVN submitted) but the
  /// virtual account number is not on the user yet — provisioning / webhooks pending.
  bool get shouldShowHomeKycPendingWalletProvisioning {
    if (hasProvisionedWalletAccountNumber) return false;
    final t = communalTier?.trim().toLowerCase() ?? '';
    return t == 'tier_1' || t == 'tier_2';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'];
    final userData = userMap is Map
        ? Map<String, dynamic>.from(userMap)
        : Map<String, dynamic>.from(json);
    final profileRaw = userData['profile'];
    final profile = profileRaw is Map
        ? Map<String, dynamic>.from(profileRaw)
        : null;

    final topRole = json['role']?.toString();
    final role =
        (topRole != null && topRole.isNotEmpty)
            ? topRole
            : (userData['role']?.toString() ?? 'member');

    String fullName = '';
    if (profile != null) {
      final parts = [
        profile['first_name'],
        profile['middle_name'],
        profile['last_name'],
      ]
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      fullName = parts.join(' ');
    }

    final fallbackName =
        userData['username']?.toString() ??
        userData['name']?.toString() ??
        '';

    final emailVal = userData['email']?.toString().trim();
    final phoneVal = userData['phone']?.toString().trim();
    final loginRaw = userData['login']?.toString().trim();

    String loginVal = '';
    for (final c in [emailVal, phoneVal, loginRaw]) {
      if (c != null && c.isNotEmpty) {
        loginVal = c;
        break;
      }
    }

    final fn = profile?['first_name']?.toString().trim();
    final mn = profile?['middle_name']?.toString().trim();
    final ln = profile?['last_name']?.toString().trim();

    String? communalTierVal;
    final rawTier = profile?['tier']?.toString().trim();
    if (rawTier != null && rawTier.isNotEmpty) {
      communalTierVal = rawTier;
    }
    String? kycStatusVal;
    final rawKyc = profile?['kyc']?.toString().trim();
    if (rawKyc != null && rawKyc.isNotEmpty) {
      kycStatusVal = rawKyc;
    }
    String? kycWorkflowStatusVal;

    String? kycAnchorId;
    bool kycStep1SubmittedVal = false;
    bool kycStep2SubmittedVal = false;
    bool kycStep3SubmittedVal = false;
    final kycRaw = json['kyc'];
    if (kycRaw is Map) {
      final k = Map<String, dynamic>.from(kycRaw);
      final aid = k['anchor_customer_id']?.toString().trim();
      if (aid != null && aid.isNotEmpty) kycAnchorId = aid;
      final workflow = k['status']?.toString().trim();
      if (workflow != null && workflow.isNotEmpty) {
        kycWorkflowStatusVal = workflow;
      }
    }
    final kycProgressRaw = json['kyc_progress'];
    if (kycProgressRaw is Map) {
      final kp = Map<String, dynamic>.from(kycProgressRaw);
      bool asBool(dynamic v) =>
          v == true || v == 1 || v == '1' || v == 'true';
      kycStep1SubmittedVal = asBool(kp['step_1_submitted']);
      kycStep2SubmittedVal = asBool(kp['step_2_submitted']);
      kycStep3SubmittedVal = asBool(kp['step_3_submitted']);
    }

    final tierLimitsRaw = json['tier_limits'];
    final tierLimitsParsed = tierLimitsRaw is Map
        ? TierLimitsSnapshot.fromJson(Map<String, dynamic>.from(tierLimitsRaw))
        : null;

    String? profileCountryIso;
    final rawCountry = profile?['country']?.toString().trim();
    if (rawCountry != null &&
        rawCountry.length == 2 &&
        RegExp(r'^[A-Za-z]{2}$').hasMatch(rawCountry)) {
      profileCountryIso = rawCountry.toUpperCase();
    }

    String? coopName;
    String? coopLogo;
    final coopRaw = profile?['cooperative'];
    if (coopRaw is Map) {
      final c = Map<String, dynamic>.from(coopRaw);
      final cn = c['cooperative_name']?.toString().trim();
      if (cn != null && cn.isNotEmpty) coopName = cn;
      final lu = c['logo_url']?.toString().trim();
      if (lu != null && lu.isNotEmpty) coopLogo = lu;
    }

    String? pickFirstCsv(String? primary, String? fallback) {
      final p = primary?.trim();
      if (p != null && p.isNotEmpty) return p;
      final f = fallback?.trim();
      if (f == null || f.isEmpty) return null;
      final comma = f.indexOf(',');
      return comma == -1 ? f : f.substring(0, comma).trim();
    }

    int walletKobo = 0;
    String? walletAcctNum;
    String? walletAcctName;
    String? walletAcctStatus;
    String? walletFrozenByVal;
    final walletRaw = userData['wallet'];
    if (walletRaw is Map) {
      final w = Map<String, dynamic>.from(walletRaw);
      final bal = w['account_balance'] ?? w['balance'];
      if (bal is int) {
        walletKobo = bal;
      } else if (bal != null) {
        walletKobo = int.tryParse(bal.toString()) ?? 0;
      }
      String? nz(String? s) {
        final t = s?.trim();
        if (t == null || t.isEmpty) return null;
        return t;
      }

      walletAcctNum = nz(w['account_number']?.toString()) ??
          nz(w['deposit_account_number']?.toString());
      walletAcctName = nz(w['account_name']?.toString()) ??
          nz(w['deposit_account_name']?.toString());
      walletAcctStatus = w['account_status']?.toString().trim();
      walletFrozenByVal = w['frozen_by']?.toString().trim();
    }

    return UserModel(
      id: userData['id']?.toString() ?? '',
      name: fullName.isNotEmpty ? fullName : fallbackName,
      login: loginVal,
      avatar: profile?['avatar']?.toString(),
      hasSecurityPin:
          userData['has_security_pin'] == true ||
          userData['has_security_pin'] == 1,
      role: role,
      cooperativeId: pickFirstCsv(
        profile?['active_cooperative_id']?.toString(),
        profile?['cooperative_id']?.toString(),
      ),
      cooperativeName: coopName,
      cooperativeLogoUrl: coopLogo,
      ledgerNumber: pickFirstCsv(
        profile?['active_ledger_number']?.toString(),
        profile?['ledger_number']?.toString(),
      ),
      firstName: fn != null && fn.isNotEmpty ? fn : null,
      middleName: mn != null && mn.isNotEmpty ? mn : null,
      lastName: ln != null && ln.isNotEmpty ? ln : null,
      email: emailVal != null && emailVal.isNotEmpty ? emailVal : null,
      phone: phoneVal != null && phoneVal.isNotEmpty ? phoneVal : null,
      countryIso: profileCountryIso,
      communalTier: communalTierVal,
      kycStatus: kycStatusVal,
      kycWorkflowStatus: kycWorkflowStatusVal,
      kycAnchorCustomerId: kycAnchorId,
      kycStep1Submitted: kycStep1SubmittedVal,
      kycStep2Submitted: kycStep2SubmittedVal,
      kycStep3Submitted: kycStep3SubmittedVal,
      tierLimits: tierLimitsParsed,
      walletBalanceKobo: walletKobo,
      walletAccountNumber: walletAcctNum,
      walletAccountName: walletAcctName,
      walletAccountStatus: walletAcctStatus,
      walletFrozenBy: walletFrozenByVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'login': login,
      'avatar': avatar,
      'has_security_pin': hasSecurityPin,
      'role': role,
      'cooperative_id': cooperativeId,
      'cooperative_name': cooperativeName,
      'cooperative_logo_url': cooperativeLogoUrl,
      'ledger_number': ledgerNumber,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'country_iso': countryIso,
      'communal_tier': communalTier,
      'kyc_status': kycStatus,
      'kyc_workflow_status': kycWorkflowStatus,
      'kyc_anchor_customer_id': kycAnchorCustomerId,
      'kyc_step_1_submitted': kycStep1Submitted,
      'kyc_step_2_submitted': kycStep2Submitted,
      'kyc_step_3_submitted': kycStep3Submitted,
      'wallet_balance_kobo': walletBalanceKobo,
      'wallet_account_number': walletAccountNumber,
      'wallet_account_name': walletAccountName,
      'wallet_account_status': walletAccountStatus,
      'wallet_frozen_by': walletFrozenBy,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        login,
        avatar,
        hasSecurityPin,
        role,
        cooperativeId,
        cooperativeName,
        cooperativeLogoUrl,
        ledgerNumber,
        firstName,
        middleName,
        lastName,
        email,
        phone,
        countryIso,
        communalTier,
        kycStatus,
        kycWorkflowStatus,
        kycAnchorCustomerId,
        kycStep1Submitted,
        kycStep2Submitted,
        kycStep3Submitted,
        tierLimits,
        walletBalanceKobo,
        walletAccountNumber,
        walletAccountName,
        walletAccountStatus,
        walletFrozenBy,
      ];
}
