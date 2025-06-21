// import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/screens/splash/splash_screen.dart';
// import 'package:communal_mobile/core/features/wallet/screens/pages/wallet_page.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'splash',
      builder: (context, state) => const SplashScreen(),
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
