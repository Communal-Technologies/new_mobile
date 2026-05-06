/// Audit M41: single source of truth for every backend endpoint the
/// mobile client hits. Repos used to embed route strings inline; that
/// made (a) finding all callers of an endpoint impossible without a
/// codebase-wide grep, and (b) renaming a backend route an N-file
/// search-and-replace.
///
/// Conventions
/// -----------
/// - Static-string endpoints are `static const String`.
/// - Path-parameter endpoints are `static String foo(...)` builder
///   methods so the call site reads `ApiEndpoints.lgas(stateId)` instead
///   of `'/fetch-lgas/$stateId'`.
/// - Grouped by feature area (auth, transfer, kyc, ...) to mirror the
///   backend's `routes/api.php` + `routes/members.php` split.
/// - Trailing slashes match the backend's expectation. **Do not add
///   `${AppConstants.baseUrl}` here** — that's set on `dio.options.baseUrl`.
class ApiEndpoints {
  ApiEndpoints._();

  // --- Auth ---------------------------------------------------------------
  static const String login = '/login';
  static const String loginChecker = '/login-checker';
  static const String sessionTakeoverVerify = '/login/session-takeover/verify';
  static const String sessionTakeoverResendOtp =
      '/login/session-takeover/resend-otp';
  static const String refreshToken = '/refresh-token';
  static const String getLoggedInUser = '/get-loggedin-user';
  static const String createAccountPassword = '/create-account-password';
  static const String generatePasswordResetLink =
      '/generate-password-reset-link';
  static const String verifyPasswordResetPin = '/verify-password-reset-pin';
  static const String resetPassword = '/reset-password';
  static const String otpSend = '/otp/send';
  static const String otpVerify = '/otp/verify';
  static const String otpDeliveryStatus = '/otp/delivery-status';

  // --- Profile ------------------------------------------------------------
  static const String profileDeviceToken = '/profile/device-token';

  // --- Members account / settings -----------------------------------------
  static const String membersUpdateSecurityPin = '/members/update-security-pin';
  static const String membersVerifySecurityPin = '/members/verify-security-pin';
  static const String membersRequestUnfreeze =
      '/members/account/request-unfreeze';
  static const String membersCommunitySettings = '/members/community-settings';
  static String membersCommunitySettingsForCooperative(String cooperativeId) =>
      '/members/community-settings/$cooperativeId';
  static const String membersRedeemInviteCode = '/members/redeem-invite-code';
  static const String fetchCooperatives = '/fetch-cooperatives';
  static String fetchCooperativeProfile(String id) =>
      '/fetch-cooperative-profile/$id';
  static const String membersJoinRequests = '/members/join-requests';
  static const String membersJoinRequestsMine = '/members/join-requests/mine';
  static String membersJoinRequestCancel(String id) =>
      '/members/join-requests/$id/cancel';
  static const String membersNotifications = '/members/notifications';
  static const String membersNotificationsUnreadCount =
      '/members/notifications/unread-count';
  static String membersNotificationRead(String id) =>
      '/members/notifications/$id/read';
  static const String membersNotificationsMarkAllRead =
      '/members/notifications/mark-all-read';
  static const String membersNotificationPreferences =
      '/members/notification-preferences';
  static String membersFetchUserDetails(String id) =>
      '/members/fetch-user-details/$id';
  static const String membersUpdateProfile = '/members/update-profile';
  static const String membersUploadAvatar = '/members/profile/avatar';
  static const String membersAccountFreeze = '/members/account/freeze';
  static const String membersAccountClosureSubmit =
      '/members/account-closure/submit';
  static const String membersTransactionStatementExport =
      '/members/transaction-statement/export';

  // --- Transfer -----------------------------------------------------------
  static const String transferBanks = '/transfer/banks';
  static const String transferBankSuggestions = '/transfer/bank-suggestions';
  static const String transferCreateCounterParties =
      '/transfer/create-counter-parties';
  static String transferVerifyAccount(String bankCode, String accountNumber) =>
      '/transfer/verify-account/${bankCode.trim()}/${accountNumber.trim()}';
  static const String transferInitiate = '/transfer/initiate';
  static const String membersTransferBeneficiaries =
      '/members/transfer/beneficiaries';
  static String membersTransferStatus(String transferId) =>
      '/members/transfer/transactions/$transferId/status';

  // --- Bill payments (airtime, data, electricity, television via Anchor) -
  static const String billsAirtimeProviders = '/bills/airtime/providers';
  static const String billsDataProviders = '/bills/data/providers';
  static const String billsElectricityProviders = '/bills/electricity/providers';
  static const String billsTelevisionProviders = '/bills/television/providers';
  static String billsBillerProducts(String billerId) =>
      '/bills/billers/${billerId.trim()}/products';
  static const String billsAirtimePurchase = '/bills/airtime/purchase';
  static const String billsDataPurchase = '/bills/data/purchase';
  static const String billsElectricityPurchase = '/bills/electricity/purchase';
  static const String billsTelevisionPurchase = '/bills/television/purchase';
  /// Pre-purchase meter (electricity) or smartcard (television) lookup.
  /// `billerSlug` is the provider's slug (e.g. `ikeja_electric_prepaid`,
  /// `dstv`); `accountNumber` is the meter / smartcard.
  static String billsCustomerValidation(String billerSlug, String accountNumber) =>
      '/bills/customer-validation/${billerSlug.trim()}/${accountNumber.trim()}';
  static String billsTransactionByReference(String reference) =>
      '/bills/transactions/${reference.trim()}';

  // --- Members ledger / obligations ---------------------------------------
  static String membersFinancialObligations(
    String ledgerNumber,
    String cooperativeId,
  ) => '/members/financial-obligations/$ledgerNumber/$cooperativeId';
  static String membersFines(String ledgerNumber, String cooperativeId) =>
      '/members/fines/$ledgerNumber/$cooperativeId';
  static const String membersCooperativeCashRepositories =
      '/members/cooperative-cash-repositories';
  static String membersFetchMemberTransactions(String ledgerNumber) =>
      '/members/fetch-member-transactions/$ledgerNumber';
  static String membersFetchTransactions(String userId) =>
      '/members/fetch-transactions/$userId';

  /// Single-transaction fetch by trx_reference OR external_reference,
  /// scoped to the authenticated member. Used for push-tap deep
  /// linking into the receipt screen. 404 outside the caller's scope.
  static String membersTransactionByReference(String reference) =>
      '/members/transactions/by-reference/$reference';

  /// Single-obligation fetch keyed by id. Server returns
  /// `{obligation: …, account: …}` — both halves needed by
  /// `Obligation.fromBackend`. 404 when the row doesn't belong to
  /// the authenticated member.
  static String membersObligationById(String id) => '/members/obligations/$id';
  static const String membersPayObligation = '/members/pay-obligation';

  /// Record-only path for NIP-funded obligation payments. Backend skips
  /// the biometric-sig middleware here because the upstream
  /// `/transfer/initiate` already signed the value-moving step; this
  /// call is bookkeeping. Without this split, the second biometric
  /// prompt on the receipt screen silently failed when the user
  /// dismissed it or biometric wasn't enrolled, leaving the wallet
  /// debited but the obligation un-credited.
  static const String membersRecordNipObligationPayment =
      '/members/record-nip-obligation-payment';

  // --- Loans --------------------------------------------------------------
  static String membersFetchLoanSchemes(String cooperativeId) =>
      '/members/fetch-loan-schemes/$cooperativeId';
  static String membersFetchUserLoans(String ledgerNumber, [String? status]) =>
      status == null || status.trim().isEmpty
      ? '/members/loan/fetch-requested/$ledgerNumber'
      : '/members/loan/fetch-requested/$ledgerNumber/${status.trim()}';
  static String membersFetchLoanBalance(String ledgerNumber) =>
      '/members/loan/fetch-balances/$ledgerNumber';

  /// Per-loan member-scoped reads — installment schedule and the
  /// regrant chain rooted at this loan. Both 404 on a loan that
  /// doesn't belong to the calling member's MemberCooperative
  /// mapping; the controllers do not reveal existence.
  static String membersFetchLoanInstallments(String loanId) =>
      '/loans/$loanId/installments';
  static String membersFetchLoanRegrantChain(String loanId) =>
      '/loans/$loanId/regrant-chain';

  /// Loan-by-id fetch used by the push-tap deep-link. Endpoint lives on
  /// the shared auth group at /v1/fetch-loan-details/{id} (see
  /// backend routes/api.php:180), and returns
  /// `{ "loanDetail": { … } }`.
  static String fetchLoanDetailsById(String id) => '/fetch-loan-details/$id';
  static String membersLoanEligibility(String cooperativeId) =>
      '/members/loan/eligibility/$cooperativeId';
  static String membersFetchGuarantorRequests(String ledgerNumber) =>
      '/members/loan/fetch-approval-requests/$ledgerNumber';
  static const String membersLoanApplication = '/members/loan/application';
  static const String membersLoanCancelRequest = '/members/loan/cancel-request';

  /// Per-loan guarantor list with name + status + expiry. Used by the
  /// applicant's loan-detail screen to render the per-guarantor card
  /// with remind/replace actions.
  static String membersGuarantorsForLoan(String loanRef) =>
      '/members/loan/guarantors/for-loan/$loanRef';

  /// Re-fire the guarantor invitation SMS / push for a still-pending
  /// approval row (rate-limited 24h, pre-expiry only — backend
  /// enforces both).
  static String membersGuarantorRemind(String approvalId) =>
      '/members/loan/guarantors/$approvalId/remind';

  /// Swap a still-unresolved (or expired) guarantor for a new one.
  static const String membersGuarantorReplace =
      '/members/loan/guarantors/replace';

  /// Member-initiated loan repayment (obligation→loan path).
  /// Biometric-gated server-side. Mirrors the obligation flow.
  static const String membersPayLoan = '/members/loan/pay';

  /// NIP-funded loan repayment record-only path. No biometric; the
  /// upstream /transfer/initiate already signed the value-moving
  /// step. Same split as record-nip-obligation-payment.
  static const String membersRecordNipLoanPayment =
      '/members/loan/record-nip-payment';
  static const String membersUpdateGuarantorApproval =
      '/members/loan/update-guarantor-approval';
  static const String membersLoanSearchGuarantors =
      '/members/loan/search-guarantors';

  // --- KYC / compliance ---------------------------------------------------
  static String complianceRegister(String userId) =>
      '/compliance/register/$userId';
  static String complianceUpgradeTier1(String anchorCustomerId) =>
      '/compliance/upgrade-to-tier1/$anchorCustomerId';
  static String complianceUpgradeTier2(String anchorCustomerId) =>
      '/compliance/upgrade-to-tier2/$anchorCustomerId';
  static String complianceRecordConsent(String anchorCustomerId) =>
      '/compliance/record-consent/$anchorCustomerId';

  // --- Regions / locations ------------------------------------------------
  static const String fetchRegions = '/fetch-regions';
  static const String fetchStates = '/fetch-states';
  static String fetchLgas(Object stateId) => '/fetch-lgas/$stateId';
  static String fetchInternalAccounts(String cooperativeId) =>
      '/fetch-internal-accounts/$cooperativeId';

  // --- Security / biometric (audit M7, M38) -------------------------------
  static const String securityVerifyPassword =
      '/security/transaction/verify-password';
  static const String biometricEnroll = '/security/biometric/enroll';
  static const String biometricChallenge = '/security/biometric/challenge';
  static const String biometricRevoke = '/security/biometric/revoke';
  static const String biometricStatus = '/security/biometric/status';
}
