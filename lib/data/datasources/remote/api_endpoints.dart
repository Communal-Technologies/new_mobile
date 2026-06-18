/// Audit M41: single source of truth for every backend endpoint the
/// mobile client hits. Repos used to embed route strings inline; that
/// made (a) finding all callers of an endpoint impossible without a
/// codebase-wide grep, and (b) renaming a backend route an N-file
/// search-and-replace.
///
/// Conventions
/// -----------
/// - `dio.options.baseUrl` is the **origin only** (scheme + host, e.g.
///   `https://api.communalhq.com`). It carries no path prefix.
/// - Every endpoint below is a path that begins with its own service
///   prefix, so each route is self-describing and resolves correctly
///   regardless of which service serves it:
///     - Monolith (Laravel) → `/api/v1/…`
///     - KYC micro-service   → `/api/kyc/v2/…`
///     - Bills micro-service → `/api/bills/v2/…`
/// - Dio merges `baseUrl + path` by plain concatenation, so an origin
///   base + a fully-prefixed path is exactly the final URL.
class ApiEndpoints {
  ApiEndpoints._();

  /// Monolith (Laravel) version prefix. Every monolith route is mounted
  /// under this on the API gateway.
  static const String _v1 = '/api/v1';

  /// Bills micro-service prefix. The bills service runs at `/api/bills/v2/…`.
  static const String _billsV2 = '/api/bills/v2';

  // --- Auth ---------------------------------------------------------------
  static const String login = '$_v1/login';
  static const String loginChecker = '$_v1/login-checker';
  static const String sessionTakeoverVerify =
      '$_v1/login/session-takeover/verify';
  static const String sessionTakeoverResendOtp =
      '$_v1/login/session-takeover/resend-otp';
  static const String refreshToken = '$_v1/refresh-token';
  static const String getLoggedInUser = '$_v1/get-loggedin-user';
  static const String createAccountPassword = '$_v1/create-account-password';
  static const String generatePasswordResetLink =
      '$_v1/generate-password-reset-link';
  static const String verifyPasswordResetPin = '$_v1/verify-password-reset-pin';
  static const String resetPassword = '$_v1/reset-password';
  static const String otpSend = '$_v1/otp/send';
  static const String otpVerify = '$_v1/otp/verify';
  static const String otpDeliveryStatus = '$_v1/otp/delivery-status';

  // --- Profile ------------------------------------------------------------
  static const String profileDeviceToken = '$_v1/profile/device-token';

  // --- Members account / settings -----------------------------------------
  static const String membersChangePassword = '$_v1/members/change-password';
  static const String memberLoginActivity = '$_v1/auth/login-activity';
  static const String membersUpdateSecurityPin =
      '$_v1/members/update-security-pin';
  static const String membersVerifySecurityPin =
      '$_v1/members/verify-security-pin';
  static const String membersRequestUnfreeze =
      '$_v1/members/account/request-unfreeze';
  static const String membersCommunitySettings =
      '$_v1/members/community-settings';
  static String membersCommunitySettingsForCooperative(String cooperativeId) =>
      '$_v1/members/community-settings/$cooperativeId';
  static const String membersRedeemInviteCode =
      '$_v1/members/redeem-invite-code';
  static const String fetchCooperatives = '$_v1/fetch-cooperatives';
  static String fetchCooperativeProfile(String id) =>
      '$_v1/fetch-cooperative-profile/$id';
  static const String membersJoinRequests = '$_v1/members/join-requests';
  static const String membersJoinRequestsMine =
      '$_v1/members/join-requests/mine';
  static String membersJoinRequestCancel(String id) =>
      '$_v1/members/join-requests/$id/cancel';
  static const String membersNotifications = '$_v1/members/notifications';
  static const String membersNotificationsUnreadCount =
      '$_v1/members/notifications/unread-count';
  static String membersNotificationRead(String id) =>
      '$_v1/members/notifications/$id/read';
  static const String membersNotificationsMarkAllRead =
      '$_v1/members/notifications/mark-all-read';
  static const String membersNotificationPreferences =
      '$_v1/members/notification-preferences';
  static String membersFetchUserDetails(String id) =>
      '$_v1/members/fetch-user-details/$id';
  static const String membersUpdateProfile = '$_v1/members/update-profile';
  static const String membersUploadAvatar = '$_v1/members/profile/avatar';
  static const String membersAccountFreeze = '$_v1/members/account/freeze';
  static const String membersAccountClosureSubmit =
      '$_v1/members/account-closure/submit';
  static const String membersTransactionStatementExport =
      '$_v1/members/transaction-statement/export';

  // --- Transfer -----------------------------------------------------------
  static const String transferBanks = '$_v1/transfer/banks';
  static const String transferBankSuggestions =
      '$_v1/transfer/bank-suggestions';
  static const String transferCreateCounterParties =
      '$_v1/transfer/create-counter-parties';
  static String transferVerifyAccount(String bankCode, String accountNumber) =>
      '$_v1/transfer/verify-account/${bankCode.trim()}/${accountNumber.trim()}';
  static const String transferInitiate = '$_v1/transfer/initiate';
  static const String transferFee = '$_v1/transfer/fee';
  static const String membersTransferBeneficiaries =
      '$_v1/members/transfer/beneficiaries';
  static String membersTransferStatus(String transferId) =>
      '$_v1/members/transfer/transactions/$transferId/status';

  // --- Bill payments (bills micro-service at /api/bills/v2) ---------------
  /// Providers list. Pass `?category=AIRTIME|DATA|ELECTRICITY|TELEVISION`.
  static const String billsBillers = '$_billsV2/billers';

  static String billsBillerProducts(String billerId) =>
      '$_billsV2/billers/${billerId.trim()}/products';

  /// Pre-purchase meter (electricity) or smartcard (television) lookup.
  static String billsCustomerValidation(
          String billerSlug, String accountNumber) =>
      '$_billsV2/validate/${billerSlug.trim()}/${accountNumber.trim()}';

  static const String billsAirtimePurchase = '$_billsV2/airtime';
  static const String billsDataPurchase = '$_billsV2/data';
  static const String billsElectricityPurchase = '$_billsV2/electricity';
  static const String billsTelevisionPurchase = '$_billsV2/cable';

  static String billsTransactionByReference(String reference) =>
      '$_billsV2/transactions/${reference.trim()}';

  // --- Members ledger / obligations ---------------------------------------
  static String membersFinancialObligations(
    String ledgerNumber,
    String cooperativeId,
  ) => '$_v1/members/financial-obligations/$ledgerNumber/$cooperativeId';
  static String membersFines(String ledgerNumber, String cooperativeId) =>
      '$_v1/members/fines/$ledgerNumber/$cooperativeId';
  static const String membersCooperativeCashRepositories =
      '$_v1/members/cooperative-cash-repositories';
  static String membersFetchMemberTransactions(String ledgerNumber) =>
      '$_v1/members/fetch-member-transactions/$ledgerNumber';
  static String membersFetchTransactions(String userId) =>
      '$_v1/members/fetch-transactions/$userId';

  /// Single-transaction fetch by trx_reference OR external_reference,
  /// scoped to the authenticated member. Used for push-tap deep
  /// linking into the receipt screen. 404 outside the caller's scope.
  static String membersTransactionByReference(String reference) =>
      '$_v1/members/transactions/by-reference/$reference';

  /// Single-obligation fetch keyed by id. Server returns
  /// `{obligation: …, account: …}` — both halves needed by
  /// `Obligation.fromBackend`. 404 when the row doesn't belong to
  /// the authenticated member.
  static String membersObligationById(String id) =>
      '$_v1/members/obligations/$id';
  static const String membersObligationWithdrawal =
      '$_v1/members/obligation-withdrawal';
  static String membersRevokeObligationWithdrawal(String id) =>
      '$_v1/members/obligation-withdrawal/$id';

  static const String membersPayObligation = '$_v1/members/pay-obligation';
  static const String membersPayFine = '$_v1/members/pay-fine';
  static const String membersRecordNipFinePayment =
      '$_v1/members/record-nip-fine-payment';

  /// Record-only path for NIP-funded obligation payments. Backend skips
  /// the biometric-sig middleware here because the upstream
  /// `/transfer/initiate` already signed the value-moving step; this
  /// call is bookkeeping. Without this split, the second biometric
  /// prompt on the receipt screen silently failed when the user
  /// dismissed it or biometric wasn't enrolled, leaving the wallet
  /// debited but the obligation un-credited.
  static const String membersRecordNipObligationPayment =
      '$_v1/members/record-nip-obligation-payment';

  // --- Loans --------------------------------------------------------------
  static String membersFetchLoanSchemes(String cooperativeId) =>
      '$_v1/members/fetch-loan-schemes/$cooperativeId';
  static String membersFetchUserLoans(String ledgerNumber, [String? status]) =>
      status == null || status.trim().isEmpty
      ? '$_v1/members/loan/fetch-requested/$ledgerNumber'
      : '$_v1/members/loan/fetch-requested/$ledgerNumber/${status.trim()}';
  static String membersFetchLoanBalance(String ledgerNumber) =>
      '$_v1/members/loan/fetch-balances/$ledgerNumber';

  /// Per-loan member-scoped reads — installment schedule and the
  /// regrant chain rooted at this loan. Both 404 on a loan that
  /// doesn't belong to the calling member's MemberCooperative
  /// mapping; the controllers do not reveal existence.
  static String membersFetchLoanInstallments(String loanId) =>
      '$_v1/loans/$loanId/installments';
  static String membersFetchLoanRegrantChain(String loanId) =>
      '$_v1/loans/$loanId/regrant-chain';

  /// Loan-by-id fetch used by the push-tap deep-link. Endpoint lives on
  /// the shared auth group at /v1/fetch-loan-details/{id} (see
  /// backend routes/api.php:180), and returns
  /// `{ "loanDetail": { … } }`.
  static String fetchLoanDetailsById(String id) =>
      '$_v1/fetch-loan-details/$id';
  static String membersLoanEligibility(String cooperativeId) =>
      '$_v1/members/loan/eligibility/$cooperativeId';
  static String membersFetchGuarantorRequests(String ledgerNumber) =>
      '$_v1/members/loan/fetch-approval-requests/$ledgerNumber';
  static const String membersLoanApplication = '$_v1/members/loan/application';
  static const String membersLoanCancelRequest =
      '$_v1/members/loan/cancel-request';

  /// Per-loan guarantor list with name + status + expiry. Used by the
  /// applicant's loan-detail screen to render the per-guarantor card
  /// with remind/replace actions.
  static String membersGuarantorsForLoan(String loanRef) =>
      '$_v1/members/loan/guarantors/for-loan/$loanRef';

  /// Re-fire the guarantor invitation SMS / push for a still-pending
  /// approval row (rate-limited 24h, pre-expiry only — backend
  /// enforces both).
  static String membersGuarantorRemind(String approvalId) =>
      '$_v1/members/loan/guarantors/$approvalId/remind';

  /// Swap a still-unresolved (or expired) guarantor for a new one.
  static const String membersGuarantorReplace =
      '$_v1/members/loan/guarantors/replace';

  /// Member-initiated loan repayment (obligation→loan path).
  /// Biometric-gated server-side. Mirrors the obligation flow.
  static const String membersPayLoan = '$_v1/members/loan/pay';

  /// NIP-funded loan repayment record-only path. No biometric; the
  /// upstream /transfer/initiate already signed the value-moving
  /// step. Same split as record-nip-obligation-payment.
  static const String membersRecordNipLoanPayment =
      '$_v1/members/loan/record-nip-payment';
  static const String membersUpdateGuarantorApproval =
      '$_v1/members/loan/update-guarantor-approval';
  static const String membersLoanSearchGuarantors =
      '$_v1/members/loan/search-guarantors';

  // --- KYC / compliance (kycsvc — /api/kyc/v2/...) ------------------------
  static const String kycCreate = '/api/kyc/v2';
  static String kycGetByUserId(String userId) => '/api/kyc/v2/user/$userId';
  static const String kycRecordConsent = '/api/kyc/v2/consent';
  static String kycUpgradeTier1(String anchorCustomerId) =>
      '/api/kyc/v2/$anchorCustomerId/tier1';
  static String kycUpgradeTier2(String anchorCustomerId) =>
      '/api/kyc/v2/$anchorCustomerId/tier2';

  // --- Regions / locations ------------------------------------------------
  static const String fetchRegions = '$_v1/fetch-regions';
  static const String fetchStates = '$_v1/fetch-states';
  static String fetchLgas(Object stateId) => '$_v1/fetch-lgas/$stateId';
  static String fetchInternalAccounts(String cooperativeId) =>
      '$_v1/fetch-internal-accounts/$cooperativeId';

  // --- Security / biometric (audit M7, M38) -------------------------------
  static const String securityVerifyPassword =
      '$_v1/security/transaction/verify-password';
  static const String biometricEnroll = '$_v1/security/biometric/enroll';
  static const String biometricChallenge = '$_v1/security/biometric/challenge';
  static const String biometricRevoke = '$_v1/security/biometric/revoke';
  static const String biometricStatus = '$_v1/security/biometric/status';
}
