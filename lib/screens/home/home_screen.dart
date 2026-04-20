import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/cooperative_sidebar.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/screens/home/widgets/home_account_card_section.dart';
import 'package:communal_mobile/screens/home/widgets/home_account_frozen_card.dart';
import 'package:communal_mobile/screens/home/widgets/home_header.dart';
import 'package:communal_mobile/screens/home/widgets/kyc_alert.dart';
import 'package:communal_mobile/screens/home/widgets/quick_actions_section.dart';
import 'package:communal_mobile/screens/home/widgets/recent_transactions_section.dart';
import 'package:communal_mobile/screens/home/widgets/new_feature_banner.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.grey.shade50,
        drawer: const CooperativeSidebar(),
        drawerEdgeDragWidth: 50.w,
        drawerScrimColor: Colors.black.withValues(
          alpha: 0.4,
        ), // Darker overlay for better visibility
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                HomeHeader(
                  scaffoldKey: _scaffoldKey,
                  theme: theme,
                ),

                vSpace(16),

                BlocBuilder<AuthBloc, AuthState>(
                  buildWhen: (prev, next) {
                    String? wan(AuthState s) =>
                        s is AuthAuthenticated ? s.user.walletAccountNumber : null;
                    return wan(prev) != wan(next) ||
                        prev.runtimeType != next.runtimeType;
                  },
                  builder: (context, authState) {
                    if (authState is AuthAuthenticated) {
                      final u = authState.user;
                      final hasWalletAccountNumber =
                          u.walletAccountNumber != null &&
                              u.walletAccountNumber!.trim().isNotEmpty;
                      // Balance card only after wallet provisioning (KYC path); ledger alone is not enough.
                      if (hasWalletAccountNumber) {
                        return HomeAccountCardSection(user: u);
                      }
                    }
                    return const KycAlert();
                  },
                ),

                vSpace(16),

                BlocBuilder<AuthBloc, AuthState>(
                  buildWhen: (prev, next) {
                    if (prev.runtimeType != next.runtimeType) return true;
                    if (prev is AuthAuthenticated && next is AuthAuthenticated) {
                      return prev.user != next.user;
                    }
                    return true;
                  },
                  builder: (context, authState) {
                    if (authState is AuthAuthenticated) {
                      return HomeAccountFrozenCard(user: authState.user);
                    }
                    return const SizedBox.shrink();
                  },
                ),

                vSpace(20),

                // Quick Actions
                QuickActionsSection(theme: theme),

                vSpace(24),

                // Recent Transactions
                const RecentTransactionsSection(),

                vSpace(20),

                // New Feature Banner
                NewFeatureBanner(theme: theme),

                vSpace(100),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BottomNavBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            if (index == _currentIndex && index == 0) return;
            switch (index) {
              case 0:
                setState(() {
                  _currentIndex = 0;
                });
                break;
              case 1:
                context.pushNamed('obligations');
                break;
              case 2:
                context.pushNamed('community');
                break;
              case 3:
                context.goNamed('loans');
                break;
              case 4:
                context.goNamed('account-settings');
                break;
              default:
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Coming soon')));
            }
          },
        ),
      ),
    );
  }
}
