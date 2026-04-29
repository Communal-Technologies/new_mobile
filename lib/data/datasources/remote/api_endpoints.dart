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
  static const String generatePasswordResetLink = '/generate-password-reset-link';
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
  static const String membersRequestUnfreeze = '/members/account/request-unfreeze';
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
  static const String membersAccountClosureSubmit = '/members/account-closure/submit';
  static const String membersTransactionStatementExport =
      '/members/transaction-statement/export';

  // --- Transfer -----------------------------------------------------------
  static const String transferBanks = '/transfer/banks';
  static const String transferBankSuggestions = '/transfer/bank-suggestions';
  static const String transferCreateCounterParties = '/transfer/create-counter-parties';
  static String transferVerifyAccount(String bankCode, String accountNumber) =>
      '/transfer/verify-account/${bankCode.trim()}/${accountNumber.trim()}';
  static const String transferInitiate = '/transfer/initiate';
  static const String membersTransferBeneficiaries = '/members/transfer/beneficiaries';
  static String membersTransferStatus(String transferId) =>
      '/members/transfer/transactions/$transferId/status';

  // --- Members ledger / obligations ---------------------------------------
  static String membersFinancialObligations(
          String ledgerNumber, String cooperativeId) =>
      '/members/financial-obligations/$ledgerNumber/$cooperativeId';
  static const String membersCooperativeCashRepositories =
      '/members/cooperative-cash-repositories';
  static String membersFetchMemberTransactions(String ledgerNumber) =>
      '/members/fetch-member-transactions/$ledgerNumber';
  static String membersFetchTransactions(String userId) =>
      '/members/fetch-transactions/$userId';
  static const String membersPayObligation = '/members/pay-obligation';

  // --- Loans --------------------------------------------------------------
  static String membersFetchLoanSchemes(String cooperativeId) =>
      '/members/fetch-loan-schemes/$cooperativeId';
  static String membersFetchUserLoans(String ledgerNumber, [String? status]) =>
      status == null || status.trim().isEmpty
          ? '/members/loan/fetch-requested/$ledgerNumber'
          : '/members/loan/fetch-requested/$ledgerNumber/${status.trim()}';
  static String membersFetchLoanBalance(String ledgerNumber) =>
      '/members/loan/fetch-balances/$ledgerNumber';
  static String membersLoanEligibility(String cooperativeId) =>
      '/members/loan/eligibility/$cooperativeId';
  static String membersFetchGuarantorRequests(String ledgerNumber) =>
      '/members/loan/fetch-approval-requests/$ledgerNumber';
  static const String membersLoanApplication = '/members/loan/application';
  static const String membersLoanCancelRequest = '/members/loan/cancel-request';
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

  // --- Regions / locations ------------------------------------------------
  static const String fetchRegions = '/fetch-regions';
  static const String fetchStates = '/fetch-states';
  static String fetchLgas(Object stateId) => '/fetch-lgas/$stateId';
  static String fetchInternalAccounts(String cooperativeId) =>
      '/fetch-internal-accounts/$cooperativeId';

  // --- Security / biometric (audit M7, M38) -------------------------------
  static const String securityVerifyPassword = '/security/transaction/verify-password';
  static const String biometricEnroll = '/security/biometric/enroll';
  static const String biometricChallenge = '/security/biometric/challenge';
  static const String biometricRevoke = '/security/biometric/revoke';
  static const String biometricStatus = '/security/biometric/status';
}
