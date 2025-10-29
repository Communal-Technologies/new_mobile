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
import 'package:communal_mobile/screens/transactions/transaction_history_screen.dart';
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
        
        return VerifyResetScreen(
          contact: contact,
          isEmail: isEmail,
        );
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
    
    // Transaction History
    GoRoute(
      path: '/transactions',
      name: 'transactions',
      builder: (context, state) => const TransactionHistoryScreen(),
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
