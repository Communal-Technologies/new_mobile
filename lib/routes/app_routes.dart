// import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
import 'package:communal_mobile/screens/auth/password_reset_success_screen.dart';
import 'package:communal_mobile/screens/kyc/profile_information_screen.dart';
import 'package:communal_mobile/screens/kyc/bank_information_screen.dart';
import 'package:communal_mobile/screens/kyc/proof_of_identity_screen.dart';
import 'package:communal_mobile/screens/kyc/verifying_identity_screen.dart';
import 'package:communal_mobile/screens/kyc/all_set_screen.dart';
import 'package:communal_mobile/screens/home/home_screen.dart';
import 'package:communal_mobile/screens/obligations/data/sample_obligations.dart';
import 'package:communal_mobile/screens/obligations/financial_obligations_screen.dart';
import 'package:communal_mobile/screens/obligations/obligation_detail_screen.dart';
import 'package:communal_mobile/screens/obligations/obligation_payment_screen.dart';
import 'package:communal_mobile/screens/obligations/obligation_confirm_payment_screen.dart';
import 'package:communal_mobile/screens/obligations/obligation_payment_success_screen.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:communal_mobile/screens/transactions/transaction_details_screen.dart';
import 'package:communal_mobile/screens/transactions/transaction_history_screen.dart';
import 'package:communal_mobile/screens/transactions/transaction_receipt_screen.dart';
// import 'package:communal_mobile/core/features/wallet/screens/pages/wallet_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
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
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/welcome-back',
      name: 'welcome-back',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final phone = extra?['phone'] ?? '';
        final method = extra?['method'] ?? 'pin';

        return WelcomeBackScreen(
          phoneNumber: phone,
          method: method == 'pin'
              ? SignInMethod.pin
              : method == 'fingerprint'
              ? SignInMethod.fingerprint
              : SignInMethod.password,
        );
      },
    ),

    // Password Reset Flow
    GoRoute(
      path: '/forgot-password',
      name: 'forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/verify-reset',
      name: 'verify-reset',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final contact = extra?['contact'] ?? '';
        final isEmail = extra?['isEmail'] ?? true;

        return VerifyResetScreen(contact: contact, isEmail: isEmail);
      },
    ),
    GoRoute(
      path: '/reset-password',
      name: 'reset-password',
      builder: (context, state) => const ResetPasswordScreen(),
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

        return PhoneVerificationScreen(
          phoneNumber: phone,
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
      builder: (context, state) => const SetPinScreen(),
    ),
    GoRoute(
      path: '/set-password',
      name: 'set-password',
      builder: (context, state) => const SetPasswordScreen(),
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
      path: '/obligations',
      name: 'obligations',
      builder: (context, state) => const FinancialObligationsScreen(),
    ),
    GoRoute(
      path: '/obligation-detail',
      name: 'obligation-detail',
      builder: (context, state) {
        final extra = state.extra;
        final obligation = extra is Obligation
            ? extra
            : SampleObligations.all.first;
        return ObligationDetailScreen(obligation: obligation);
      },
    ),
    GoRoute(
      path: '/obligation-payment',
      name: 'obligation-payment',
      builder: (context, state) {
        final extra = state.extra;
        final obligation = extra is Obligation
            ? extra
            : SampleObligations.all.first;
        return ObligationPaymentScreen(obligation: obligation);
      },
    ),
    GoRoute(
      path: '/obligation-confirm-payment',
      name: 'obligation-confirm-payment',
      builder: (context, state) {
        Obligation obligation = SampleObligations.all.first;
        double amount = obligation.perInstallment;
        String method = 'Wallet';

        final extra = state.extra;
        if (extra is Map) {
          final maybeObligation = extra['obligation'];
          if (maybeObligation is Obligation) {
            obligation = maybeObligation;
          }
          final maybeAmount = extra['amount'];
          if (maybeAmount is num) {
            amount = maybeAmount.toDouble();
          }
          final maybeMethod = extra['method'];
          if (maybeMethod is String) {
            method = maybeMethod;
          }
        }

        return ObligationConfirmPaymentScreen(
          obligation: obligation,
          amount: amount,
          method: method,
        );
      },
    ),
    GoRoute(
      path: '/obligation-payment-success',
      name: 'obligation-payment-success',
      builder: (context, state) {
        Obligation obligation = SampleObligations.all.first;
        double amount = obligation.perInstallment;
        String method = 'Wallet';
        String reference = 'REF-${DateTime.now().millisecondsSinceEpoch}';
        DateTime date = DateTime.now();

        final extra = state.extra;
        if (extra is Map) {
          final maybeObligation = extra['obligation'];
          if (maybeObligation is Obligation) {
            obligation = maybeObligation;
          }
          final maybeAmount = extra['amount'];
          if (maybeAmount is num) {
            amount = maybeAmount.toDouble();
          }
          final maybeMethod = extra['method'];
          if (maybeMethod is String && maybeMethod.isNotEmpty) {
            method = maybeMethod;
          }
          final maybeReference = extra['reference'];
          if (maybeReference is String && maybeReference.isNotEmpty) {
            reference = maybeReference;
          }
          final maybeDate = extra['date'];
          if (maybeDate is DateTime) {
            date = maybeDate;
          }
        }

        return ObligationPaymentSuccessScreen(
          obligation: obligation,
          amount: amount,
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

        if (extra is Map<String, dynamic>) {
          final maybeDetails = extra['details'];
          if (maybeDetails is TransactionDetailsData) {
            details = maybeDetails;
          }
          action = _parseReceiptAction(extra['action']);
        } else if (extra is TransactionDetailsData) {
          details = extra;
        }

        return TransactionReceiptScreen(
          details: details,
          initialAction: action,
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
