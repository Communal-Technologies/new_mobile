import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_number_input/intl_phone_number_input.dart';
import 'package:communal_mobile/data/models/member_profile_details.dart';
import 'package:communal_mobile/core/utils/app_logger.dart';
import 'package:communal_mobile/routes/auth_status_notifier.dart';

import 'package:communal_mobile/core/navigation/root_navigator_key.dart';

import 'package:communal_mobile/screens/splash/splash_screen.dart';
import 'package:communal_mobile/screens/onboarding/onboarding_screen.dart';
import 'package:communal_mobile/screens/welcome/welcome_screen.dart';
import 'package:communal_mobile/screens/auth/signup_screen.dart';
import 'package:communal_mobile/screens/auth/login_screen.dart';
import 'package:communal_mobile/screens/auth/welcome_back_screen.dart';
import 'package:communal_mobile/screens/auth/phone_verification_screen.dart';
import 'package:communal_mobile/screens/auth/set_pin_screen.dart';
import 'package:communal_mobile/screens/auth/set_password_screen.dart';
import 'package:communal_mobile/screens/auth/account_success_screen.dart';
import 'package:communal_mobile/screens/auth/forgot_password_screen.dart';
import 'package:communal_mobile/screens/auth/verify_reset_screen.dart';
import 'package:communal_mobile/screens/auth/reset_password_screen.dart';
import 'package:communal_mobile/screens/auth/session_takeover_screen.dart';
import 'package:communal_mobile/screens/auth/password_reset_success_screen.dart';
import 'package:communal_mobile/screens/kyc/profile_information_screen.dart';
import 'package:communal_mobile/screens/kyc/bank_information_screen.dart';
import 'package:communal_mobile/screens/kyc/proof_of_identity_screen.dart';
import 'package:communal_mobile/screens/kyc/verifying_identity_screen.dart';
import 'package:communal_mobile/screens/kyc/all_set_screen.dart';
import 'package:communal_mobile/screens/home/home_screen.dart';
import 'package:communal_mobile/screens/notifications/notifications_screen.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:communal_mobile/screens/obligations/financial_obligations_screen.dart';
import 'package:communal_mobile/screens/obligations/obligation_detail_screen.dart';
import 'package:communal_mobile/screens/obligations/obligation_payment_screen.dart';
import 'package:communal_mobile/screens/obligations/obligation_confirm_payment_screen.dart';
import 'package:communal_mobile/screens/obligations/obligation_payment_success_screen.dart';
import 'package:communal_mobile/data/repositories/member_obligations_repository.dart';
import 'package:communal_mobile/screens/community/community_screen.dart';
import 'package:communal_mobile/screens/community/community_map_screen.dart';
import 'package:communal_mobile/screens/community/community_detail_screen.dart';
import 'package:communal_mobile/screens/community/community_application_status_screen.dart';
import 'package:communal_mobile/screens/community/data/sample_community_details.dart';
import 'package:communal_mobile/screens/community/data/sample_community_locations.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:communal_mobile/screens/transactions/transaction_details_screen.dart';
import 'package:communal_mobile/screens/transactions/transaction_history_screen.dart';
import 'package:communal_mobile/screens/obligations/data/obligation_nip_settlement.dart';
import 'package:communal_mobile/screens/transactions/transaction_receipt_screen.dart';
import 'package:communal_mobile/screens/transactions/transfer_external_screen.dart';
import 'package:communal_mobile/screens/transactions/transfer_internal_amount_screen.dart';
import 'package:communal_mobile/screens/transactions/transfer_internal_screen.dart';
import 'package:communal_mobile/screens/transactions/transfer_internal_verify_screen.dart';
import 'package:communal_mobile/screens/transactions/transfer_internal_review_screen.dart';
import 'package:communal_mobile/screens/transactions/transfer_screen.dart';
import 'package:communal_mobile/data/local/transfer_favorites_prefs.dart';
import 'package:communal_mobile/data/models/loan_scheme.dart';
import 'package:communal_mobile/data/models/loan_application.dart';
import 'package:communal_mobile/screens/loans/loans_screen.dart';
import 'package:communal_mobile/screens/loans/loan_calculator_screen.dart';
import 'package:communal_mobile/screens/loans/loan_application_screen.dart';
import 'package:communal_mobile/screens/loans/loan_application_step2_screen.dart';
import 'package:communal_mobile/screens/loans/loan_application_step3_screen.dart';
import 'package:communal_mobile/screens/loans/loan_application_success_screen.dart';
import 'package:communal_mobile/screens/loans/loan_detail_screen.dart';
import 'package:communal_mobile/screens/loans/loan_payment_screen.dart';
import 'package:communal_mobile/screens/loans/loan_confirm_payment_screen.dart';
import 'package:communal_mobile/screens/loans/data/loan_nip_settlement.dart';
import 'package:communal_mobile/screens/loans/guarantor_requests_screen.dart';
import 'package:communal_mobile/screens/loans/data/loan_application_draft.dart';
import 'package:communal_mobile/screens/account/account_settings_screen.dart';
import 'package:communal_mobile/screens/account/my_profile_screen.dart';
import 'package:communal_mobile/screens/account/freeze_account_screen.dart';
import 'package:communal_mobile/screens/account/freeze_account_pin_screen.dart';
import 'package:communal_mobile/screens/account/freeze_account_success_screen.dart';
import 'package:communal_mobile/screens/account/edit_profile_screen.dart';
import 'package:communal_mobile/screens/account/invite_and_earn_screen.dart';
import 'package:communal_mobile/screens/account/account_limits_screen.dart';
import 'package:communal_mobile/screens/account/community_settings_screen.dart';
import 'package:communal_mobile/screens/account/help_support_screen.dart';
import 'package:communal_mobile/screens/account/faq_screen.dart';
import 'package:communal_mobile/screens/account/notification_settings_screen.dart';
import 'package:communal_mobile/screens/account/security_settings_screen.dart';
import 'package:communal_mobile/screens/account/biometric_enrollment_screen.dart';
import 'package:communal_mobile/screens/account/change_transaction_pin_screen.dart';
import 'package:communal_mobile/screens/account/delete_account_screen.dart';
import 'package:communal_mobile/screens/account/delete_account_confirmation_screen.dart';
import 'package:communal_mobile/screens/account/delete_account_feedback_screen.dart';
import 'package:communal_mobile/screens/account/delete_account_pin_screen.dart';
import 'package:communal_mobile/screens/account/delete_account_final_confirmation_screen.dart';
import 'package:communal_mobile/screens/account/delete_account_success_screen.dart';
// import 'package:communal_mobile/core/features/wallet/screens/pages/wallet_page.dart';

/// Routes the user can reach without an authenticated session.
///
/// Splash + onboarding + the full pre-login flow (signup, OTP, password set,
/// password reset). Every other route is treated as protected and gated by
/// the [redirect] callback below. Audit M29.
const Set<String> _publicPaths = <String>{
  '/',
  '/onboarding',
  '/welcome',
  '/login',
  '/welcome-back',
  '/session-takeover',
  '/signup',
  '/verify-phone',
  '/set-pin',
  '/set-password',
  '/account-success',
  '/forgot-password',
  '/verify-reset',
  '/reset-password',
  '/password-reset-success',
};

/// Routes the post-login KYC gate considers part of the KYC flow. While
/// the user's KYC is incomplete every other protected route bounces back
/// to `/kyc/profile-info`; staying on these is allowed so the user can
/// actually finish the form. `/account-success` is also tolerated so a
/// fresh signup that lands on the account-success screen can proceed
/// into the KYC flow without an interim bounce.
const Set<String> _kycPaths = <String>{
  '/kyc/profile-info',
  '/kyc/bank-info',
  '/kyc/proof-of-identity',
  '/kyc/verifying',
  '/kyc/all-set',
};

/// Routes that require cooperative membership. Non-coop users hitting
/// any of these are redirected to `/home`. Match by prefix because the
/// loan flow has many sub-paths (apply, step2, step3, success, detail).
bool _requiresCooperative(String loc) {
  return loc == '/loans' ||
      loc.startsWith('/loan-') ||
      loc == '/loan-calculator' ||
      loc == '/guarantor-requests' ||
      loc.startsWith('/obligations') ||
      loc.startsWith('/obligation-');
}

String? _authRedirect(Object _, GoRouterState state) {
  // The router runs `redirect` on the very first build before AuthBloc has
  // emitted anything beyond `AuthInitial`. Don't bounce anyone until we know
  // for sure — splash will hold them on `/` until the first resolved state.
  if (!appAuthStatusNotifier.isResolved) return null;

  final loc = state.matchedLocation;
  if (_publicPaths.contains(loc)) return null;
  if (!appAuthStatusNotifier.isAuthenticated) {
    // Protected route, no session — back to login.
    return '/login';
  }

  // Authenticated. KYC gate: a brand-new user who hasn't submitted any
  // KYC step or earned a tier is held inside the KYC flow until they
  // either submit step 1 (which flips `hasCompletedKyc` to true) or
  // get approved to tier_1+. The check intentionally lets users who
  // are *pending review* through — they've done their part, no point
  // making them redo the form while admins review.
  if (!appAuthStatusNotifier.hasCompletedKyc && !_kycPaths.contains(loc)) {
    return '/kyc/profile-info';
  }

  // Cooperative-only routes: loans, obligations, guarantor inbox, the
  // loan calculator. Non-coop members can still browse the app, they
  // just can't reach these. Send them home.
  if (!appAuthStatusNotifier.hasCooperative && _requiresCooperative(loc)) {
    return '/home';
  }

  return null;
}

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/',
  refreshListenable: appAuthStatusNotifier,
  redirect: _authRedirect,
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, state) => const OnBoardingScreen(),
    ),
    GoRoute(
      path: '/welcome',
      name: 'welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),

    // Auth routes - Signup
    GoRoute(
      path: '/signup',
      name: 'signup',
      builder: (context, state) => const SignupScreen(),
    ),

    // Auth routes - Login
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) {
        final extra = state.extra is Map<String, dynamic>
            ? state.extra as Map<String, dynamic>
            : const <String, dynamic>{};
        final phoneArg = extra['phoneNumber'];
        return LoginScreen(
          initialPhone: phoneArg is PhoneNumber ? phoneArg : null,
        );
      },
    ),
    GoRoute(
      path: '/welcome-back',
      name: 'welcome-back',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final phone = extra?['phone'] ?? '';
        // Default to fingerprint if method not specified (biometric is default)
        final method = extra?['method'] ?? 'fingerprint';
        // If isAppLock is true, hide back button (for logged-in but unauthorized users)
        final isAppLock = extra?['isAppLock'] == true;

        return WelcomeBackScreen(
          phoneNumber: phone,
          method: method == 'fingerprint'
              ? SignInMethod.fingerprint
              : method == 'pin'
              ? SignInMethod.pin
              : SignInMethod.password,
          isAppLock: isAppLock,
        );
      },
    ),
    GoRoute(
      path: '/session-takeover',
      name: 'session-takeover',
      builder: (context, state) => const SessionTakeoverScreen(),
    ),

    // Password Reset Flow
    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final preFilledContact = extra?['preFilledContact'] as String?;
        AppLogger.debug(
          'Route',
          'forgot-password preFilled=${preFilledContact != null}',
        );
        return ForgotPasswordScreen(preFilledContact: preFilledContact);
      },
    ),
    GoRoute(
      path: '/verify-reset',
      name: 'verify-reset',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final contact = extra?['contact'] ?? '';
        final isEmail = extra?['isEmail'] ?? true;
        final isInitialSetup = extra?['isInitialSetup'] ?? false;
        final isForgotPassword = extra?['isForgotPassword'] ?? false;
        final userId = extra?['userId']?.toString();
        final skipInitialOtpRequest = extra?['skipInitialOtpRequest'] == true;

        return VerifyResetScreen(
          contact: contact,
          isEmail: isEmail,
          isInitialSetup: isInitialSetup,
          isForgotPassword: isForgotPassword,
          userId: userId,
          skipInitialOtpRequest: skipInitialOtpRequest,
        );
      },
    ),
    GoRoute(
      path: '/reset-password',
      name: 'reset-password',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return ResetPasswordScreen(
          userId: extra?['userId']?.toString(),
          contact: extra?['contact']?.toString(),
          pin: extra?['pin']?.toString(),
          isInitialSetup: extra?['isInitialSetup'] == true,
        );
      },
    ),
    GoRoute(
      path: '/password-reset-success',
      name: 'password-reset-success',
      builder: (context, state) => const PasswordResetSuccessScreen(),
    ),
    GoRoute(
      path: '/verify-phone',
      name: 'verify-phone',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final phone = extra?['phone'] ?? '';
        final method = extra?['method'] ?? 'sms';
        final userId = extra?['userId']?.toString();

        return PhoneVerificationScreen(
          phoneNumber: phone,
          userId: userId == null || userId.isEmpty ? null : userId,
          method: method == 'sms'
              ? VerificationMethod.sms
              : method == 'whatsapp'
              ? VerificationMethod.whatsapp
              : VerificationMethod.call,
        );
      },
    ),
    GoRoute(
      path: '/set-pin',
      name: 'set-pin',
      builder: (context, state) {
        final extra = state.extra is Map<String, dynamic>
            ? state.extra as Map<String, dynamic>
            : const <String, dynamic>{};
        return SetPinScreen(
          phone: extra['phone']?.toString(),
          userId: extra['userId']?.toString(),
        );
      },
    ),
    GoRoute(
      path: '/set-password',
      name: 'set-password',
      builder: (context, state) {
        final extra = state.extra is Map<String, dynamic>
            ? state.extra as Map<String, dynamic>
            : const <String, dynamic>{};
        return SetPasswordScreen(
          phone: extra['phone']?.toString(),
          userId: extra['userId']?.toString(),
        );
      },
    ),
    GoRoute(
      path: '/account-success',
      name: 'account-success',
      builder: (context, state) => const AccountSuccessScreen(),
    ),

    // KYC routes
    GoRoute(
      path: '/kyc/profile-info',
      name: 'kyc-profile-info',
      builder: (context, state) => const ProfileInformationScreen(),
    ),
    // Audit M30: anchorCustomerId is no longer accepted from `state.extra`
    // (a crafted intent could plant another user's id). The screens read
    // it from KycProgressStorage keyed by the authenticated user's id —
    // the trusted value written by `saveAfterProfileRegistered` after the
    // /compliance/register call.
    GoRoute(
      path: '/kyc/bank-info',
      name: 'kyc-bank-info',
      builder: (context, state) => const BankInformationScreen(),
    ),
    GoRoute(
      path: '/kyc/proof-of-identity',
      name: 'kyc-proof-of-identity',
      builder: (context, state) => const ProofOfIdentityScreen(),
    ),
    GoRoute(
      path: '/kyc/verifying',
      name: 'kyc-verifying',
      builder: (context, state) => const VerifyingIdentityScreen(),
    ),
    GoRoute(
      path: '/kyc/all-set',
      name: 'kyc-all-set',
      builder: (context, state) => const AllSetScreen(),
    ),

    // Home screen
    GoRoute(
      path: '/home',
      name: 'home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/community',
      name: 'community',
      builder: (context, state) => const CommunityScreen(),
    ),
    GoRoute(
      path: '/community-map',
      name: 'community-map',
      builder: (context, state) => const CommunityMapScreen(),
    ),
    GoRoute(
      path: '/community-detail',
      name: 'community-detail',
      redirect: (context, state) {
        if (state.extra is CommunityLocation) return null;
        return '/community';
      },
      builder: (context, state) {
        // Defensive: GoRouter redirects don't re-run on every rebuild
        // (page-restoration / state-tick paths can hit the builder with
        // a null extra). Guard the cast so we never crash; the
        // post-frame redirect bounces back to the listing.
        final extra = state.extra;
        if (extra is! CommunityLocation) {
          return _MissingExtraRedirect(target: '/community');
        }
        final detail = SampleCommunityDetails.forLocation(extra);
        return CommunityDetailScreen(detail: detail);
      },
    ),
    GoRoute(
      path: '/community-application-status',
      name: 'community-application-status',
      redirect: (context, state) {
        if (state.extra is CommunityLocation) return null;
        return '/community';
      },
      builder: (context, state) {
        final extra = state.extra;
        if (extra is! CommunityLocation) {
          return _MissingExtraRedirect(target: '/community');
        }
        final detail = SampleCommunityDetails.forLocation(extra);
        return CommunityApplicationStatusScreen(detail: detail);
      },
    ),
    GoRoute(
      path: '/obligations',
      name: 'obligations',
      builder: (context, state) => const FinancialObligationsScreen(),
    ),
    GoRoute(
      path: '/loans',
      name: 'loans',
      builder: (context, state) => const LoansScreen(),
    ),
    GoRoute(
      path: '/loan-calculator',
      name: 'loan-calculator',
      builder: (context, state) => const LoanCalculatorScreen(),
    ),
    // Audit M27: route extras are type-checked before any numeric conversion.
    GoRoute(
      path: '/loan-application',
      name: 'loan-application',
      builder: (context, state) {
        final extra = state.extra is Map<String, dynamic>
            ? state.extra as Map<String, dynamic>
            : const <String, dynamic>{};
        return LoanApplicationScreen(
          preselectedScheme:
              extra['scheme'] is LoanScheme ? extra['scheme'] as LoanScheme : null,
          initialAmount: (extra['amount'] as num?)?.toDouble(),
        );
      },
    ),
    GoRoute(
      path: '/loan-application-step2',
      name: 'loan-application-step2',
      builder: (context, state) {
        final extra = state.extra is Map<String, dynamic>
            ? state.extra as Map<String, dynamic>
            : const <String, dynamic>{};
        final draft = extra['draft'];
        if (draft is! LoanApplicationDraft) {
          // Hard-redirect back to the start of the flow if someone
          // deep-links into step 2 without the draft state.
          return const LoanApplicationScreen();
        }
        return LoanApplicationStep2Screen(draft: draft);
      },
    ),
    GoRoute(
      path: '/loan-application-step3',
      name: 'loan-application-step3',
      builder: (context, state) {
        final extra = state.extra is Map<String, dynamic>
            ? state.extra as Map<String, dynamic>
            : const <String, dynamic>{};
        final draft = extra['draft'];
        if (draft is! LoanApplicationDraft) {
          return const LoanApplicationScreen();
        }
        return LoanApplicationStep3Screen(draft: draft);
      },
    ),
    GoRoute(
      path: '/loan-detail',
      name: 'loan-detail',
      builder: (context, state) {
        final extra = state.extra is Map<String, dynamic>
            ? state.extra as Map<String, dynamic>
            : const <String, dynamic>{};
        final loan = extra['loan'];
        if (loan is! LoanApplication) {
          return const LoansScreen();
        }
        return LoanDetailScreen(loan: loan);
      },
    ),
    GoRoute(
      path: '/loan-payment',
      name: 'loan-payment',
      redirect: (context, state) =>
          state.extra is LoanApplication ? null : '/loans',
      builder: (context, state) =>
          LoanPaymentScreen(loan: state.extra as LoanApplication),
    ),
    GoRoute(
      path: '/loan-confirm-payment',
      name: 'loan-confirm-payment',
      redirect: (context, state) {
        final extra = state.extra;
        if (extra is! Map) return '/loans';
        if (extra['loan'] is! LoanApplication) return '/loans';
        return null;
      },
      builder: (context, state) {
        final extra = Map<String, dynamic>.from(state.extra as Map);
        final loan = extra['loan'] as LoanApplication;

        final maybeAmount = extra['amountMinor'] ?? extra['amount_minor'];
        final amountMinor = maybeAmount is num
            ? maybeAmount.toInt()
            : int.tryParse(maybeAmount?.toString() ?? '') ??
                loan.monthlyRepaymentMinor;

        final maybeMethod = extra['method'];
        final method = maybeMethod is String && maybeMethod.isNotEmpty
            ? maybeMethod
            : 'Wallet';

        CooperativeCashBankAccount? cashAccount;
        final rawCash = extra['cash_account'];
        if (rawCash is Map) {
          cashAccount = CooperativeCashBankAccount.fromJson(
            Map<String, dynamic>.from(rawCash),
          );
        }

        String? cashRepositoryId;
        final rawRid = extra['cash_repository_id'];
        if (rawRid != null) {
          final rid = rawRid.toString().trim();
          cashRepositoryId = rid.isEmpty ? null : rid;
        }

        String? sourceObligationCode;
        final rawSrcCode = extra['source_obligation_code'];
        if (rawSrcCode != null) {
          final code = rawSrcCode.toString().trim();
          sourceObligationCode = code.isEmpty ? null : code;
        }

        String? sourceObligationTitle;
        final rawSrcTitle = extra['source_obligation_title'];
        if (rawSrcTitle != null) {
          final title = rawSrcTitle.toString().trim();
          sourceObligationTitle = title.isEmpty ? null : title;
        }

        return LoanConfirmPaymentScreen(
          loan: loan,
          amountMinor: amountMinor,
          method: method,
          cashAccount: cashAccount,
          cashRepositoryId: cashRepositoryId,
          sourceObligationCode: sourceObligationCode,
          sourceObligationTitle: sourceObligationTitle,
        );
      },
    ),
    GoRoute(
      path: '/guarantor-requests',
      name: 'guarantor-requests',
      builder: (context, state) => const GuarantorRequestsScreen(),
    ),
    GoRoute(
      path: '/loan-application-success',
      name: 'loan-application-success',
      builder: (context, state) {
        final extra = state.extra is Map<String, dynamic>
            ? state.extra as Map<String, dynamic>
            : const <String, dynamic>{};
        return LoanApplicationSuccessScreen(
          amountMinor: (extra['amountMinor'] as num?)?.toInt() ?? 0,
          currency: extra['currency'] is String
              ? (extra['currency'] as String)
              : 'NGN',
          referenceId: extra['referenceId'] is String
              ? extra['referenceId'] as String
              : null,
          message: extra['message'] is String
              ? extra['message'] as String
              : null,
        );
      },
    ),
    GoRoute(
      path: '/account-settings',
      name: 'account-settings',
      builder: (context, state) => const AccountSettingsScreen(),
    ),
    GoRoute(
      path: '/my-profile',
      name: 'my-profile',
      builder: (context, state) => const MyProfileScreen(),
    ),
    GoRoute(
      path: '/freeze-account',
      name: 'freeze-account',
      builder: (context, state) => const FreezeAccountScreen(),
    ),
    GoRoute(
      path: '/freeze-account-pin',
      name: 'freeze-account-pin',
      builder: (context, state) {
        final extra = state.extra;
        final reason = extra is Map && extra['reason'] is String
            ? extra['reason'] as String
            : null;
        return FreezeAccountPinScreen(reason: reason);
      },
    ),
    GoRoute(
      path: '/freeze-account-success',
      name: 'freeze-account-success',
      builder: (context, state) => const FreezeAccountSuccessScreen(),
    ),
    GoRoute(
      path: '/edit-profile',
      name: 'edit-profile',
      // EditProfileScreen requires the loaded MemberProfileDetails so
      // the form starts hydrated with the user's actual values; reject
      // missing extras instead of letting the screen crash.
      redirect: (context, state) {
        final extra = state.extra;
        if (extra is Map && extra['profile'] is MemberProfileDetails) {
          return null;
        }
        return '/my-profile';
      },
      builder: (context, state) {
        final extra = state.extra as Map;
        return EditProfileScreen(
          profile: extra['profile'] as MemberProfileDetails,
          isAddressOnly: extra['isAddressOnly'] == true,
        );
      },
    ),
    GoRoute(
      path: '/invite-and-earn',
      name: 'invite-and-earn',
      builder: (context, state) => const InviteAndEarnScreen(),
    ),
    GoRoute(
      path: '/account-limits',
      name: 'account-limits',
      builder: (context, state) => const AccountLimitsScreen(),
    ),
    GoRoute(
      path: '/community-settings',
      name: 'community-settings',
      builder: (context, state) => const CommunitySettingsScreen(),
    ),
    GoRoute(
      path: '/help-support',
      name: 'help-support',
      builder: (context, state) => const HelpSupportScreen(),
    ),
    GoRoute(
      path: '/faq',
      name: 'faq',
      builder: (context, state) => const FaqScreen(),
    ),
    GoRoute(
      path: '/notification-settings',
      name: 'notification-settings',
      builder: (context, state) => const NotificationSettingsScreen(),
    ),
    GoRoute(
      path: '/security-settings',
      name: 'security-settings',
      builder: (context, state) => const SecuritySettingsScreen(),
    ),
    GoRoute(
      path: '/biometric-enrollment',
      name: 'biometric-enrollment',
      builder: (context, state) => const BiometricEnrollmentScreen(),
    ),
    GoRoute(
      path: '/change-transaction-pin',
      name: 'change-transaction-pin',
      builder: (context, state) => const ChangeTransactionPinScreen(),
    ),
    GoRoute(
      path: '/delete-account',
      name: 'delete-account',
      builder: (context, state) => const DeleteAccountScreen(),
    ),
    GoRoute(
      path: '/delete-account-confirmation',
      name: 'delete-account-confirmation',
      builder: (context, state) => const DeleteAccountConfirmationScreen(),
    ),
    GoRoute(
      path: '/delete-account-feedback',
      name: 'delete-account-feedback',
      builder: (context, state) => const DeleteAccountFeedbackScreen(),
    ),
    GoRoute(
      path: '/delete-account-pin',
      name: 'delete-account-pin',
      builder: (context, state) => const DeleteAccountPinScreen(),
    ),
    GoRoute(
      path: '/delete-account-final-confirmation',
      name: 'delete-account-final-confirmation',
      builder: (context, state) => const DeleteAccountFinalConfirmationScreen(),
    ),
    GoRoute(
      path: '/delete-account-success',
      name: 'delete-account-success',
      builder: (context, state) => const DeleteAccountSuccessScreen(),
    ),
    GoRoute(
      path: '/obligation-detail',
      name: 'obligation-detail',
      redirect: (context, state) =>
          state.extra is Obligation ? null : '/obligations',
      builder: (context, state) =>
          ObligationDetailScreen(obligation: state.extra as Obligation),
    ),
    GoRoute(
      path: '/obligation-payment',
      name: 'obligation-payment',
      redirect: (context, state) =>
          state.extra is Obligation ? null : '/obligations',
      builder: (context, state) =>
          ObligationPaymentScreen(obligation: state.extra as Obligation),
    ),
    GoRoute(
      path: '/obligation-confirm-payment',
      name: 'obligation-confirm-payment',
      redirect: (context, state) {
        final extra = state.extra;
        if (extra is! Map) return '/obligations';
        if (extra['obligation'] is! Obligation) return '/obligations';
        return null;
      },
      builder: (context, state) {
        final extra = Map<String, dynamic>.from(state.extra as Map);
        final obligation = extra['obligation'] as Obligation;

        final maybeAmount = extra['amountMinor'] ?? extra['amount_minor'];
        final amountMinor = maybeAmount is num
            ? maybeAmount.toInt()
            : int.tryParse(maybeAmount?.toString() ?? '') ??
                obligation.perInstallmentMinor;

        final maybeMethod = extra['method'];
        final method = maybeMethod is String && maybeMethod.isNotEmpty
            ? maybeMethod
            : 'Wallet';

        CooperativeCashBankAccount? cashAccount;
        final rawCash = extra['cash_account'];
        if (rawCash is Map) {
          cashAccount = CooperativeCashBankAccount.fromJson(
            Map<String, dynamic>.from(rawCash),
          );
        }

        String? cashRepositoryId;
        final rawRid = extra['cash_repository_id'];
        if (rawRid != null) {
          final rid = rawRid.toString().trim();
          cashRepositoryId = rid.isEmpty ? null : rid;
        }

        String? sourceObligationCode;
        final rawSrcCode = extra['source_obligation_code'];
        if (rawSrcCode != null) {
          final code = rawSrcCode.toString().trim();
          sourceObligationCode = code.isEmpty ? null : code;
        }

        String? sourceObligationTitle;
        final rawSrcTitle = extra['source_obligation_title'];
        if (rawSrcTitle != null) {
          final title = rawSrcTitle.toString().trim();
          sourceObligationTitle = title.isEmpty ? null : title;
        }

        return ObligationConfirmPaymentScreen(
          obligation: obligation,
          amountMinor: amountMinor,
          method: method,
          cashAccount: cashAccount,
          cashRepositoryId: cashRepositoryId,
          sourceObligationCode: sourceObligationCode,
          sourceObligationTitle: sourceObligationTitle,
        );
      },
    ),
    GoRoute(
      path: '/obligation-payment-success',
      name: 'obligation-payment-success',
      redirect: (context, state) {
        final extra = state.extra;
        if (extra is! Map) return '/obligations';
        if (extra['obligation'] is! Obligation) return '/obligations';
        return null;
      },
      builder: (context, state) {
        final extra = Map<String, dynamic>.from(state.extra as Map);
        final obligation = extra['obligation'] as Obligation;

        final maybeAmount = extra['amountMinor'] ?? extra['amount_minor'];
        final amountMinor = maybeAmount is num
            ? maybeAmount.toInt()
            : int.tryParse(maybeAmount?.toString() ?? '') ??
                obligation.perInstallmentMinor;

        final maybeMethod = extra['method'];
        final method = maybeMethod is String && maybeMethod.isNotEmpty
            ? maybeMethod
            : 'Wallet';

        final maybeReference = extra['reference'];
        final reference = maybeReference is String && maybeReference.isNotEmpty
            ? maybeReference
            : 'REF-${DateTime.now().millisecondsSinceEpoch}';

        final maybeDate = extra['date'];
        final date = maybeDate is DateTime ? maybeDate : DateTime.now();

        return ObligationPaymentSuccessScreen(
          obligation: obligation,
          amountMinor: amountMinor,
          method: method,
          reference: reference,
          date: date,
        );
      },
    ),

    // Transaction History
    GoRoute(
      path: '/transactions',
      name: 'transactions',
      builder: (context, state) => const TransactionHistoryScreen(),
    ),
    GoRoute(
      path: '/transfer',
      name: 'transfer',
      builder: (context, state) => const TransferScreen(),
    ),
    GoRoute(
      path: '/transfer/internal',
      name: 'transfer-internal',
      builder: (context, state) {
        TransferFavorite? fav;
        final extra = state.extra;
        if (extra is Map && extra['favorite'] is Map) {
          fav = TransferFavorite.fromJson(
            Map<String, dynamic>.from(extra['favorite'] as Map),
          );
        }
        return TransferInternalScreen(initialRecipient: fav);
      },
    ),
    GoRoute(
      path: '/transfer/internal-amount',
      name: 'transfer-internal-amount',
      builder: (context, state) {
        final extra = state.extra;
        if (extra is Map && extra['favorite'] is Map) {
          final fav = TransferFavorite.fromJson(
            Map<String, dynamic>.from(extra['favorite'] as Map),
          );
          return TransferInternalAmountScreen(recipient: fav);
        }
        return TransferInternalAmountScreen(
          recipient: const TransferFavorite(
            source: 'internal',
            accountId: '',
            bank: 'Communal',
            accountNumber: '',
            accountName: 'Recipient',
          ),
        );
      },
    ),
    // Audit M20 (leaves): the review / verify / external-verify routes
    // consume `amountMinor + currency` from extras; the legacy `amountKobo`
    // shim is gone. `_extraAsMap` and `_extraAmountMinor` keep parsing
    // type-safe and isolated from the screen builders.
    GoRoute(
      path: '/transfer/internal-review',
      name: 'transfer-internal-review',
      builder: (context, state) {
        final extra = _extraAsMap(state.extra);
        final fav = _extraTransferFavorite(extra) ??
            const TransferFavorite(
              source: 'internal',
              accountId: '',
              bank: 'Communal',
              accountNumber: '',
              accountName: 'Recipient',
            );
        return TransferInternalReviewScreen(
          recipient: fav,
          amountMinor: _extraAmountMinor(extra),
          currency: _extraCurrency(extra),
          narration: (extra['narration']?.toString() ?? '').trim(),
          saveAsBeneficiary: extra['saveAsBeneficiary'] == true,
          useExternalNipFlow: extra['useExternalNipFlow'] == true,
          obligationNipSettlement: _extraObligationNipSettlement(extra),
        );
      },
    ),
    GoRoute(
      path: '/transfer/internal-verify',
      name: 'transfer-internal-verify',
      builder: (context, state) {
        final extra = _extraAsMap(state.extra);
        final fav = _extraTransferFavorite(extra) ??
            const TransferFavorite(
              source: 'internal',
              accountId: '',
              bank: 'Communal',
              accountNumber: '',
              accountName: 'Recipient',
            );
        return TransferInternalVerifyScreen(
          recipient: fav,
          amountMinor: _extraAmountMinor(extra),
          currency: _extraCurrency(extra),
          narration: (extra['narration']?.toString() ?? '').trim(),
          saveAsBeneficiary: extra['saveAsBeneficiary'] == true,
          useExternalNipFlow: extra['useExternalNipFlow'] == true,
          obligationNipSettlement: _extraObligationNipSettlement(extra),
        );
      },
    ),
    GoRoute(
      path: '/transfer/external-verify',
      name: 'transfer-external-verify',
      builder: (context, state) {
        final extra = _extraAsMap(state.extra);
        final fav = _extraTransferFavorite(extra) ??
            const TransferFavorite(
              source: 'external',
              accountId: '',
              bank: '',
              accountNumber: '',
              accountName: 'Recipient',
            );
        return TransferInternalVerifyScreen(
          recipient: fav,
          amountMinor: _extraAmountMinor(extra),
          currency: _extraCurrency(extra),
          narration: (extra['narration']?.toString() ?? '').trim(),
          saveAsBeneficiary: extra['saveAsBeneficiary'] == true,
          useExternalNipFlow: true,
          obligationNipSettlement: _extraObligationNipSettlement(extra),
        );
      },
    ),
    GoRoute(
      path: '/transfer/external',
      name: 'transfer-external',
      builder: (context, state) {
        TransferFavorite? fav;
        final extra = state.extra;
        if (extra is Map && extra['favorite'] is Map) {
          fav = TransferFavorite.fromJson(
            Map<String, dynamic>.from(extra['favorite'] as Map),
          );
        }
        return TransferExternalScreen(initialRecipient: fav);
      },
    ),
    GoRoute(
      path: '/transaction-details',
      name: 'transaction-details',
      builder: (context, state) {
        final extra = state.extra;
        final details = extra is TransactionDetailsData
            ? extra
            : kSampleTransactionDetails;
        return TransactionDetailsScreen(details: details);
      },
    ),
    GoRoute(
      path: '/transaction-receipt',
      name: 'transaction-receipt',
      builder: (context, state) {
        final extra = state.extra;
        TransactionDetailsData details = kSampleTransactionDetails;
        ReceiptAction? action;

        ObligationNipSettlement? obligationNipSettlement;
        LoanNipSettlement? loanNipSettlement;
        if (extra is Map<String, dynamic>) {
          final maybeDetails = extra['details'];
          if (maybeDetails is TransactionDetailsData) {
            details = maybeDetails;
          }
          action = _parseReceiptAction(extra['action']);
          final sRaw = extra['obligationNipSettlement'];
          if (sRaw is Map) {
            obligationNipSettlement =
                ObligationNipSettlement.tryFromJson(
              Map<String, dynamic>.from(sRaw),
            );
          }
          final lRaw = extra['loanNipSettlement'];
          if (lRaw is Map) {
            loanNipSettlement = LoanNipSettlement.tryFromJson(
              Map<String, dynamic>.from(lRaw),
            );
          }
        } else if (extra is TransactionDetailsData) {
          details = extra;
        }

        return TransactionReceiptScreen(
          details: details,
          initialAction: action,
          obligationNipSettlement: obligationNipSettlement,
          loanNipSettlement: loanNipSettlement,
        );
      },
    ),

    // GoRoute(
    //   path: '/wallet/:userId',
    //   name: 'wallet',
    //   builder: (context, state) {
    //     final userId = state.pathParameters['userId']!;
    //     return WalletPage(userId: userId);
    //   },
    // ),
  ],
);

ReceiptAction? _parseReceiptAction(dynamic value) {
  if (value is ReceiptAction) return value;
  if (value is String) {
    switch (value.toLowerCase()) {
      case 'download':
        return ReceiptAction.download;
      case 'share':
        return ReceiptAction.share;
      case 'preview':
        return ReceiptAction.preview;
    }
  }
  return null;
}

// --- Type-safe `state.extra` helpers (audit M20 + M27) ----------------------

Map<String, dynamic> _extraAsMap(Object? extra) {
  if (extra is Map<String, dynamic>) return extra;
  if (extra is Map) return Map<String, dynamic>.from(extra);
  return const <String, dynamic>{};
}

TransferFavorite? _extraTransferFavorite(Map<String, dynamic> extra) {
  final raw = extra['favorite'];
  if (raw is Map) {
    return TransferFavorite.fromJson(Map<String, dynamic>.from(raw));
  }
  return null;
}

/// Reads `amountMinor` from extras. Falls back to `0` for an unset / invalid
/// value (the screen's "default" path) — never crashes on a non-num.
int _extraAmountMinor(Map<String, dynamic> extra) {
  final v = extra['amountMinor'];
  if (v is num) return v.toInt();
  return 0;
}

/// Reads `currency` from extras. Falls back to `NGN` so a missing extra
/// matches the legacy NGN-only behavior.
String _extraCurrency(Map<String, dynamic> extra) {
  final v = extra['currency'];
  if (v is String && v.trim().length == 3) return v.trim().toUpperCase();
  return 'NGN';
}

ObligationNipSettlement? _extraObligationNipSettlement(
  Map<String, dynamic> extra,
) {
  final raw = extra['obligationNipSettlement'];
  if (raw is Map) {
    return ObligationNipSettlement.tryFromJson(
      Map<String, dynamic>.from(raw),
    );
  }
  return null;
}

/// Recovery screen used by route builders when their required `extra`
/// argument is missing. Renders a transient blank scaffold and schedules
/// a post-frame `go(target)` so the navigator settles cleanly. Used by
/// the community detail / application-status routes when GoRouter
/// rebuilds them with a null extra (page-restoration corner case).
class _MissingExtraRedirect extends StatefulWidget {
  const _MissingExtraRedirect({required this.target});

  final String target;

  @override
  State<_MissingExtraRedirect> createState() => _MissingExtraRedirectState();
}

class _MissingExtraRedirectState extends State<_MissingExtraRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(widget.target);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
