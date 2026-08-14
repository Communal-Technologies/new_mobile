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
  final String? address1;
  final String? address2;
  final String? city;
  /// Profile `state` and `lga` as names, which is how they are stored and how
  /// the KYC form's pickers identify their options.
  final String? state;
  final String? lga;
  final String? postalCode;

  /// From `profile.tier` on `get-loggedin-user` (e.g. tier_0, tier_1, tier_2).
  final String? communalTier;
  /// From `profile.kyc` webhook-driven verification status (e.g. approved, pending_review, rejected).
  final String? kycStatus;
  /// From top-level `kyc.status` workflow state (e.g. tier2_submitted, awaitingDocument).
  final String? kycWorkflowStatus;
  /// From top-level `kyc.rejection_reason` — the verification provider's own
  /// wording for why the last submission failed.
  final String? kycRejectionReason;

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

  /// Wallet `pending_balance` — funds received but not yet settled (kobo).
  final int walletPendingKobo;

  /// Wallet `ledger_balance` — total incl. uncleared funds (kobo).
  final int walletLedgerKobo;

  /// Wallet `account_number` (bank / virtual pay-in). Distinct from [ledgerNumber] on profile.
  final String? walletAccountNumber;

  /// Wallet `account_name` or `deposit_account_name` when present.
  final String? walletAccountName;

  /// Wallet `bank_name` or `deposit_bank_name` when present.
  final String? walletBankName;

  /// Wallet `account_status`: `1` = active, `2` = frozen (see backend `Wallet`).
  final String? walletAccountStatus;

  /// Wallet `frozen_by`: member user id when self-frozen; otherwise admin/system id.
  final String? walletFrozenBy;

  /// Wallet `currency` / `currency_code` when API sends ISO 4217 (e.g. NGN). Overrides country default.
  final String? walletCurrencyCode;

  /// Whether the member's cooperative subscription is currently active.
  /// `null` means no subscription record exists yet (treat as active so
  /// legacy members without a record are not falsely blocked).
  final bool? subscriptionActive;

  /// The date through which the subscription is valid (inclusive), as returned
  /// by the API. `null` when there is no subscription record.
  final String? subscriptionEndDate;

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
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.lga,
    this.postalCode,
    this.communalTier,
    this.kycStatus,
    this.kycWorkflowStatus,
    this.kycRejectionReason,
    this.kycAnchorCustomerId,
    this.kycStep1Submitted = false,
    this.kycStep2Submitted = false,
    this.kycStep3Submitted = false,
    this.tierLimits,
    this.walletBalanceKobo = 0,
    this.walletPendingKobo = 0,
    this.walletLedgerKobo = 0,
    this.walletAccountNumber,
    this.walletAccountName,
    this.walletBankName,
    this.walletAccountStatus,
    this.walletFrozenBy,
    this.walletCurrencyCode,
    this.subscriptionActive,
    this.subscriptionEndDate,
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

  /// "Far enough through KYC to use the app." The router uses this to
  /// gate every protected route after sign-in: a fresh tier_0 user with
  /// no submitted KYC step is bounced to `/kyc/profile-info` until they
  /// at least submit step 1. Once the cooperative-side reviewer
  /// approves them their tier flips to `tier_1+` and the gate falls
  /// open the same way; users who submitted but are pending review are
  /// considered "in-progress" and stay unblocked so we don't make them
  /// redo the form.
  bool get hasCompletedKyc {
    final tier = communalTier?.trim().toLowerCase();
    if (tier != null && tier.isNotEmpty && tier != 'tier_0') return true;
    return kycStep1Submitted;
  }

  /// Whether this member can perform cooperative actions (pay obligations,
  /// apply for loans, pay fines). False when `subscriptionActive` is
  /// explicitly `false`; `null` (no record) is treated as active.
  bool get isCooperativeSubscriptionActive => subscriptionActive != false;

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

  /// True when the user has a provisioned wallet AND a spendable balance.
  /// Wallet-funded actions (transfers, bill payments, and the wallet/NIP option
  /// on loan/obligation/fine payments) gate on this.
  bool get hasWalletBalance =>
      hasProvisionedWalletAccountNumber && walletBalanceKobo > 0;

  /// True when the last verification submission was turned down and the member
  /// has to submit again. Covers the outright rejection as well as the
  /// reenter-information and error outcomes, which need the same correction
  /// from the member.
  bool get isKycRejected {
    const rejected = {'rejected', 'reenter_information', 'error'};
    final s = kycStatus?.trim().toLowerCase() ?? '';
    final w = kycWorkflowStatus?.trim().toLowerCase() ?? '';
    return rejected.contains(s) || rejected.contains(w);
  }

  /// The provider's wording for the rejection, or null when none was supplied.
  String? get kycRejectionMessage {
    final r = kycRejectionReason?.trim();
    return (r == null || r.isEmpty) ? null : r;
  }

  /// Home banner: KYC step 2 (bank/BVN) is in — either the backend has already
  /// promoted the tier (tier_1/tier_2) or the tier is still tier_0 but step 2 was
  /// submitted / the workflow reports tier2_submitted — while the virtual account
  /// number is not on the user yet (provisioning / review pending).
  bool get shouldShowHomeKycPendingWalletProvisioning {
    if (hasProvisionedWalletAccountNumber || isKycRejected) return false;
    final t = communalTier?.trim().toLowerCase() ?? '';
    if (t == 'tier_1' || t == 'tier_2') return true;
    if (kycStep2Submitted) return true;
    final w = kycWorkflowStatus?.trim().toLowerCase() ?? '';
    return w == 'tier2_submitted';
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? login,
    String? avatar,
    bool? hasSecurityPin,
    String? role,
    String? cooperativeId,
    String? cooperativeName,
    String? cooperativeLogoUrl,
    String? ledgerNumber,
    String? firstName,
    String? middleName,
    String? lastName,
    String? email,
    String? phone,
    String? countryIso,
    String? address1,
    String? address2,
    String? city,
    String? state,
    String? lga,
    String? postalCode,
    String? communalTier,
    String? kycStatus,
    String? kycWorkflowStatus,
    String? kycRejectionReason,
    String? kycAnchorCustomerId,
    bool? kycStep1Submitted,
    bool? kycStep2Submitted,
    bool? kycStep3Submitted,
    TierLimitsSnapshot? tierLimits,
    int? walletBalanceKobo,
    int? walletPendingKobo,
    int? walletLedgerKobo,
    String? walletAccountNumber,
    String? walletAccountName,
    String? walletBankName,
    String? walletAccountStatus,
    String? walletFrozenBy,
    String? walletCurrencyCode,
    bool? subscriptionActive,
    String? subscriptionEndDate,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      login: login ?? this.login,
      avatar: avatar ?? this.avatar,
      hasSecurityPin: hasSecurityPin ?? this.hasSecurityPin,
      role: role ?? this.role,
      cooperativeId: cooperativeId ?? this.cooperativeId,
      cooperativeName: cooperativeName ?? this.cooperativeName,
      cooperativeLogoUrl: cooperativeLogoUrl ?? this.cooperativeLogoUrl,
      ledgerNumber: ledgerNumber ?? this.ledgerNumber,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      countryIso: countryIso ?? this.countryIso,
      address1: address1 ?? this.address1,
      address2: address2 ?? this.address2,
      city: city ?? this.city,
      state: state ?? this.state,
      lga: lga ?? this.lga,
      postalCode: postalCode ?? this.postalCode,
      communalTier: communalTier ?? this.communalTier,
      kycStatus: kycStatus ?? this.kycStatus,
      kycWorkflowStatus: kycWorkflowStatus ?? this.kycWorkflowStatus,
      kycRejectionReason: kycRejectionReason ?? this.kycRejectionReason,
      kycAnchorCustomerId: kycAnchorCustomerId ?? this.kycAnchorCustomerId,
      kycStep1Submitted: kycStep1Submitted ?? this.kycStep1Submitted,
      kycStep2Submitted: kycStep2Submitted ?? this.kycStep2Submitted,
      kycStep3Submitted: kycStep3Submitted ?? this.kycStep3Submitted,
      tierLimits: tierLimits ?? this.tierLimits,
      walletBalanceKobo: walletBalanceKobo ?? this.walletBalanceKobo,
      walletPendingKobo: walletPendingKobo ?? this.walletPendingKobo,
      walletLedgerKobo: walletLedgerKobo ?? this.walletLedgerKobo,
      walletAccountNumber: walletAccountNumber ?? this.walletAccountNumber,
      walletAccountName: walletAccountName ?? this.walletAccountName,
      walletBankName: walletBankName ?? this.walletBankName,
      walletAccountStatus: walletAccountStatus ?? this.walletAccountStatus,
      walletFrozenBy: walletFrozenBy ?? this.walletFrozenBy,
      walletCurrencyCode: walletCurrencyCode ?? this.walletCurrencyCode,
      subscriptionActive: subscriptionActive ?? this.subscriptionActive,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
    );
  }

  /// Re-keys the user to a different cooperative membership (client-side
  /// cooperative switch). The cooperative_id + ledger_number are the only keys
  /// requests are keyed by, so switching is purely a matter of swapping them
  /// (plus the display name/logo) and re-emitting the auth state.
  UserModel setActiveCooperative({
    required String cooperativeId,
    required String ledgerNumber,
    String? cooperativeName,
    String? cooperativeLogoUrl,
  }) {
    return copyWith(
      cooperativeId: cooperativeId,
      ledgerNumber: ledgerNumber,
      cooperativeName: cooperativeName,
      cooperativeLogoUrl: cooperativeLogoUrl,
    );
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
    String? kycRejectionReasonVal;

    String? kycAnchorId;
    bool kycStep1SubmittedVal = false;
    bool kycStep2SubmittedVal = false;
    bool kycStep3SubmittedVal = false;
    final kycRaw = json['kyc'];
    if (kycRaw is Map) {
      // Audit M19: only `anchor_customer_id` and `status` are read here.
      // BVN / NIN / dateOfBirth and any other Tier-1/Tier-2 identity
      // payload that the server might attach to the `kyc` blob are
      // intentionally NOT parsed — they would otherwise sit in the
      // [UserModel] in memory + persisted Bloc state long after the
      // KYC flow finished. The backend is asked to omit them outside
      // the KYC submission round trip; this parser is a defence-in-depth
      // belt for a backend regression.
      final k = Map<String, dynamic>.from(kycRaw);
      final aid = k['anchor_customer_id']?.toString().trim();
      if (aid != null && aid.isNotEmpty) kycAnchorId = aid;
      final workflow = k['status']?.toString().trim();
      if (workflow != null && workflow.isNotEmpty) {
        kycWorkflowStatusVal = workflow;
      }
      final reason = k['rejection_reason']?.toString().trim();
      if (reason != null && reason.isNotEmpty) {
        kycRejectionReasonVal = reason;
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

    String? profileField(String key) {
      final v = profile?[key]?.toString().trim();
      return (v == null || v.isEmpty) ? null : v;
    }

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
    int walletPendingKobo = 0;
    int walletLedgerKobo = 0;
    String? walletAcctNum;
    String? walletAcctName;
    String? walletBankNameVal;
    String? walletAcctStatus;
    String? walletFrozenByVal;
    String? walletCurrencyCodeVal;
    final walletRaw = userData['wallet'];
    if (walletRaw is Map) {
      final w = Map<String, dynamic>.from(walletRaw);
      final bal = w['account_balance'] ?? w['balance'];
      if (bal is int) {
        walletKobo = bal;
      } else if (bal != null) {
        walletKobo = int.tryParse(bal.toString()) ?? 0;
      }
      final pend = w['pending_balance'];
      if (pend is int) {
        walletPendingKobo = pend;
      } else if (pend != null) {
        walletPendingKobo = int.tryParse(pend.toString()) ?? 0;
      }
      final ledg = w['ledger_balance'];
      if (ledg is int) {
        walletLedgerKobo = ledg;
      } else if (ledg != null) {
        walletLedgerKobo = int.tryParse(ledg.toString()) ?? 0;
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
      walletBankNameVal = nz(w['bank_name']?.toString()) ??
          nz(w['deposit_bank_name']?.toString());
      walletAcctStatus = w['account_status']?.toString().trim();
      walletFrozenByVal = w['frozen_by']?.toString().trim();
      final curRaw =
          w['currency'] ?? w['currency_code'] ?? w['currency_iso'];
      if (curRaw != null) {
        final t = curRaw.toString().trim().toUpperCase();
        if (t.length == 3) walletCurrencyCodeVal = t;
      }
    }

    bool? subscriptionActiveVal;
    String? subscriptionEndDateVal;
    final subRaw = json['subscription'];
    if (subRaw is Map) {
      final s = Map<String, dynamic>.from(subRaw);
      final activeRaw = s['active'];
      if (activeRaw != null) {
        subscriptionActiveVal =
            activeRaw == true || activeRaw == 1 || activeRaw == '1' || activeRaw == 'true';
      }
      final edRaw = s['end_date']?.toString().trim();
      if (edRaw != null && edRaw.isNotEmpty) subscriptionEndDateVal = edRaw;
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
      address1: profileField('address_1'),
      address2: profileField('address_2'),
      city: profileField('city'),
      state: profileField('state'),
      lga: profileField('lga'),
      postalCode: profileField('postal_code'),
      communalTier: communalTierVal,
      kycStatus: kycStatusVal,
      kycWorkflowStatus: kycWorkflowStatusVal,
      kycRejectionReason: kycRejectionReasonVal,
      kycAnchorCustomerId: kycAnchorId,
      kycStep1Submitted: kycStep1SubmittedVal,
      kycStep2Submitted: kycStep2SubmittedVal,
      kycStep3Submitted: kycStep3SubmittedVal,
      tierLimits: tierLimitsParsed,
      walletBalanceKobo: walletKobo,
      walletPendingKobo: walletPendingKobo,
      walletLedgerKobo: walletLedgerKobo,
      walletAccountNumber: walletAcctNum,
      walletAccountName: walletAcctName,
      walletBankName: walletBankNameVal,
      walletAccountStatus: walletAcctStatus,
      walletFrozenBy: walletFrozenByVal,
      walletCurrencyCode: walletCurrencyCodeVal,
      subscriptionActive: subscriptionActiveVal,
      subscriptionEndDate: subscriptionEndDateVal,
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
      'address_1': address1,
      'address_2': address2,
      'city': city,
      'state': state,
      'lga': lga,
      'postal_code': postalCode,
      'communal_tier': communalTier,
      'kyc_status': kycStatus,
      'kyc_workflow_status': kycWorkflowStatus,
      'kyc_rejection_reason': kycRejectionReason,
      'kyc_anchor_customer_id': kycAnchorCustomerId,
      'kyc_step_1_submitted': kycStep1Submitted,
      'kyc_step_2_submitted': kycStep2Submitted,
      'kyc_step_3_submitted': kycStep3Submitted,
      'wallet_balance_kobo': walletBalanceKobo,
      'wallet_pending_kobo': walletPendingKobo,
      'wallet_ledger_kobo': walletLedgerKobo,
      'wallet_account_number': walletAccountNumber,
      'wallet_account_name': walletAccountName,
      'wallet_bank_name': walletBankName,
      'wallet_account_status': walletAccountStatus,
      'wallet_frozen_by': walletFrozenBy,
      'wallet_currency_code': walletCurrencyCode,
      'subscription_active': subscriptionActive,
      'subscription_end_date': subscriptionEndDate,
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
        address1,
        address2,
        city,
        state,
        lga,
        postalCode,
        communalTier,
        kycStatus,
        kycWorkflowStatus,
        kycRejectionReason,
        kycAnchorCustomerId,
        kycStep1Submitted,
        kycStep2Submitted,
        kycStep3Submitted,
        tierLimits,
        walletBalanceKobo,
        walletPendingKobo,
        walletLedgerKobo,
        walletAccountNumber,
        walletAccountName,
        walletBankName,
        walletAccountStatus,
        walletFrozenBy,
        walletCurrencyCode,
        subscriptionActive,
        subscriptionEndDate,
      ];
}
