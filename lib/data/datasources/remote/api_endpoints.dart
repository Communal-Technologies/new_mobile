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
///     - Cooperative service → `/api/cooperative/v2/…`
/// - Dio merges `baseUrl + path` by plain concatenation, so an origin
///   base + a fully-prefixed path is exactly the final URL.
class ApiEndpoints {
  ApiEndpoints._();

  /// Monolith (Laravel) version prefix. Every monolith route is mounted
  /// under this on the API gateway.
  static const String _v1 = '/api/v1';

  /// Bills micro-service prefix. The bills service runs at `/api/bills/v2/…`.
  static const String _billsV2 = '/api/bills/v2';

  /// Transactions micro-service prefix. Handles transfers, beneficiaries,
  /// and fees at `/api/transactions/v2/…`. Security-PIN verification stays
  /// on the monolith (`membersVerifySecurityPin`) — the PIN lives on
  /// tbl_users, which only the identity provider owns.
  static const String _txnV2 = '/api/transactions/v2';

  /// Loans micro-service prefix. Loans were migrated off the monolith; all
  /// member loan endpoints live at `/api/loans/v2/…` (gateway-routed to
  /// loans-svc). Responses use the `{status:"success", data:{…}}` envelope.
  static const String _loansV2 = '/api/loans/v2';

  /// Cooperative micro-service prefix. Membership, join requests, member
  /// settings, notifications, the member ledger, account freeze and closure
  /// were all migrated off the monolith to `/api/cooperative/v2/…`.
  static const String _coopV2 = '/api/cooperative/v2';

  // --- Auth ---------------------------------------------------------------
  static const String login = '$_v1/login';

  /// The one platform-wide logout. Multi-guard on the backend, so the same
  /// route serves members, cooperative admins and the admin portal.
  static const String logout = '$_v1/logout';
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
  // Unfreeze requests sit directly under /members in cooperative-svc, not
  // under /members/account like the freeze pair below.
  static const String membersRequestUnfreeze =
      '$_coopV2/members/request-unfreeze';
  static const String membersCommunitySettings =
      '$_coopV2/members/community-settings';
  static String membersCommunitySettingsForCooperative(String cooperativeId) =>
      '$_coopV2/members/community-settings/$cooperativeId';
  static const String membersRedeemInviteCode =
      '$_coopV2/members/redeem-invite-code';
  // Cooperative discovery is owned by cooperative-svc; the monolith copy is
  // gone post-migration.
  static const String fetchCooperatives = '$_coopV2/fetch-cooperatives';
  static String fetchCooperativeProfile(String id) =>
      '$_coopV2/fetch-cooperative-profile/$id';
  static String cooperativeStats(String id) => '$_coopV2/cooperative-stats/$id';
  // Member cooperative ratings are owned by cooperative-svc.
  static String cooperativeRating(String cooperativeId) =>
      '$_coopV2/cooperatives/$cooperativeId/rating';
  static String cooperativeRatingMine(String cooperativeId) =>
      '$_coopV2/cooperatives/$cooperativeId/rating/mine';
  static const String membersJoinRequests = '$_coopV2/members/join-requests';
  static const String membersJoinRequestsMine =
      '$_coopV2/members/join-requests/mine';
  static String membersJoinRequestCancel(String id) =>
      '$_coopV2/members/join-requests/$id/cancel';
  static const String membersNotifications = '$_coopV2/members/notifications';
  static const String membersNotificationsUnreadCount =
      '$_coopV2/members/notifications/unread-count';
  static String membersNotificationRead(String id) =>
      '$_coopV2/members/notifications/$id/read';
  static const String membersNotificationsMarkAllRead =
      '$_coopV2/members/notifications/mark-all-read';
  static const String membersNotificationPreferences =
      '$_coopV2/members/notification-preferences';
  static String membersFetchUserDetails(String id) =>
      '$_v1/members/fetch-user-details/$id';
  static const String membersUpdateProfile = '$_v1/members/update-profile';
  static const String membersUploadAvatar = '$_v1/members/profile/avatar';
  static const String membersAccountFreeze = '$_coopV2/members/account/freeze';
  static const String membersAccountFreezeStatus =
      '$_coopV2/members/account/freeze-status';
  static const String membersAccountClosureSubmit =
      '$_coopV2/members/account-closure/submit';
  static const String membersTransactionStatementExport =
      '$_txnV2/members/statement/export';

  // --- Transfer (transactions micro-service at /api/transactions/v2) ------
  // Security-PIN verification is the one exception — it stays on the
  // monolith (membersVerifySecurityPin above) because transactions-svc must
  // never touch tbl_users.
  static const String transferBanks = '$_txnV2/transfer/banks';
  static const String transferBankSuggestions =
      '$_txnV2/transfer/bank-suggestions';
  static const String transferCreateCounterParties =
      '$_txnV2/transfer/create-counter-parties';
  static String transferVerifyAccount(String bankCode, String accountNumber) =>
      '$_txnV2/transfer/verify-account/${bankCode.trim()}/${accountNumber.trim()}';
  static const String transferInitiate = '$_txnV2/transfer/initiate';
  static const String transferFee = '$_txnV2/transfer/fee';
  static const String membersTransferBeneficiaries =
      '$_txnV2/transfer/beneficiaries';
  static String membersTransferStatus(String transferId) =>
      '$_txnV2/transfer/transactions/$transferId/status';

  /// Transaction issue reports → Communal platform admin (transactions-svc).
  static const String transactionIssues = '$_txnV2/transaction-issues';

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
  // Obligations are owned by obligations-svc (/api/obligations/v2/...), routed
  // by the gateway to :8085.
  static const String _oblV2 = '/api/obligations/v2';
  static String membersFinancialObligations(
    String ledgerNumber,
    String cooperativeId,
  ) => '$_oblV2/$ledgerNumber/$cooperativeId';
  static String membersFines(String ledgerNumber, String cooperativeId) =>
      '$_oblV2/fines/$ledgerNumber/$cooperativeId';
  // Cash repositories are owned by cooperative-svc; the monolith copy is gone
  // post-migration.
  static const String membersCooperativeCashRepositories =
      '$_coopV2/members/cooperative-cash-repositories';
  // The member ledger is owned by cooperative-svc, which returns the full
  // history unpaginated — the three callers filter client-side (by
  // cooperative, trx_type, payment_mode, destination prefix), so a paginated
  // source would silently truncate their results.
  static String membersFetchMemberTransactions(String ledgerNumber) =>
      '$_coopV2/members/fetch-member-transactions/$ledgerNumber';
  // Personal transaction history is now served by transactions-svc (merged
  // transfers + bills, counterparty/beneficiary resolved there). The user is
  // derived from the JWT, so the userId arg is no longer part of the path.
  static String membersFetchTransactions(String userId) =>
      '$_txnV2/personal-transactions';

  /// Single-transaction fetch by trx_reference OR external_reference,
  /// scoped to the authenticated member. Used for push-tap deep
  /// linking into the receipt screen. 404 outside the caller's scope.
  static String membersTransactionByReference(String reference) =>
      '$_txnV2/transactions/by-reference/$reference';

  /// Single-obligation fetch keyed by id. Server returns
  /// `{obligation: …, account: …}` — both halves needed by
  /// `Obligation.fromBackend`. 404 when the row doesn't belong to
  /// the authenticated member.
  static String membersObligationById(String id) =>
      '$_oblV2/$id';
  static const String membersObligationWithdrawal =
      '$_oblV2/withdrawals';
  static String membersRevokeObligationWithdrawal(String id) =>
      '$_oblV2/withdrawals/$id';

  static const String membersPayObligation = '$_oblV2/payments';
  static const String membersPayFine = '$_oblV2/fines/payments';
  static const String membersRecordNipFinePayment =
      '$_oblV2/fines/payments/nip';

  /// Record-only path for NIP-funded obligation payments. Backend skips
  /// the biometric-sig middleware here because the upstream
  /// `/transfer/initiate` already signed the value-moving step; this
  /// call is bookkeeping. Without this split, the second biometric
  /// prompt on the receipt screen silently failed when the user
  /// dismissed it or biometric wasn't enrolled, leaving the wallet
  /// debited but the obligation un-credited.
  static const String membersRecordNipObligationPayment =
      '$_oblV2/payments/nip';

  // --- Loans (loans-svc — /api/loans/v2/...) ------------------------------
  // Migrated off the monolith. All responses use {status:"success", data:{…}}.
  static String membersFetchLoanSchemes(String cooperativeId) =>
      '$_loansV2/$cooperativeId/schemes';
  // status (when set) is passed as a `?status=` query param by the caller.
  static String membersFetchUserLoans(String ledgerNumber, [String? status]) =>
      '$_loansV2/member/$ledgerNumber';
  static String membersFetchLoanBalance(String ledgerNumber) =>
      '$_loansV2/member/$ledgerNumber/balance';

  static String membersFetchLoanInstallments(String loanId) =>
      '$_loansV2/$loanId/installments';
  static String membersFetchLoanRegrantChain(String loanId) =>
      '$_loansV2/$loanId/regrant-chain';

  /// Loan-by-id fetch (push-tap deep-link). loans-svc returns
  /// `{ data: { loanDetail: { … } } }`.
  static String fetchLoanDetailsById(String id) => '$_loansV2/$id';
  static String membersLoanEligibility(String cooperativeId) =>
      '$_loansV2/$cooperativeId/eligibility';
  static String membersFetchGuarantorRequests(String ledgerNumber) =>
      '$_loansV2/guarantors/requests/$ledgerNumber';
  static const String membersLoanApplication = '$_loansV2/application';
  /// Cancel a pending loan request (PUT /{id}/cancel).
  static String membersLoanCancelRequest(String loanId) =>
      '$_loansV2/$loanId/cancel';

  static String membersGuarantorsForLoan(String loanRef) =>
      '$_loansV2/guarantors/$loanRef';

  static String membersGuarantorRemind(String approvalId) =>
      '$_loansV2/guarantors/$approvalId/remind';

  static const String membersGuarantorReplace =
      '$_loansV2/guarantors/replace';

  static const String membersPayLoan = '$_loansV2/pay';

  static const String membersRecordNipLoanPayment =
      '$_loansV2/record-nip-payment';
  static const String membersUpdateGuarantorApproval =
      '$_loansV2/guarantors/update-approval';
  /// Guarantor search — caller passes `?cooperative=&q=` query params.
  static const String membersLoanSearchGuarantors =
      '$_loansV2/guarantors/search';

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
  // Internal accounts are owned by cooperative-svc.
  static String fetchInternalAccounts(String cooperativeId) =>
      '$_coopV2/fetch-internal-accounts/$cooperativeId';

  // --- Security / biometric (audit M7, M38) -------------------------------
  static const String securityVerifyPassword =
      '$_txnV2/security/transaction/verify-password';
  static const String biometricEnroll = '$_v1/security/biometric/enroll';
  static const String biometricChallenge = '$_v1/security/biometric/challenge';
  static const String biometricRevoke = '$_v1/security/biometric/revoke';
  static const String biometricStatus = '$_v1/security/biometric/status';
}
