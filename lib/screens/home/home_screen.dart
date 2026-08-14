import 'package:flutter/material.dart';
import 'package:communal_mobile/core/widgets/back_to_exit_wrapper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/bottom_nav_bar.dart';
import 'package:communal_mobile/core/widgets/cooperative_sidebar.dart';
import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/services/transaction_activity_service.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/screens/home/widgets/home_account_card_section.dart';
import 'package:communal_mobile/screens/home/widgets/home_account_frozen_card.dart';
import 'package:communal_mobile/screens/home/widgets/home_header.dart';
import 'package:communal_mobile/screens/home/widgets/kyc_alert.dart';
import 'package:communal_mobile/screens/home/widgets/kyc_pending_approval_card.dart';
import 'package:communal_mobile/screens/home/widgets/pin_setup_notice_card.dart';
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
  late final TransactionActivityService _activity =
      getIt<TransactionActivityService>();

  @override
  void initState() {
    super.initState();
    _activity.revision.addListener(_onTransactionActivity);
  }

  @override
  void dispose() {
    _activity.revision.removeListener(_onTransactionActivity);
    super.dispose();
  }

  /// A deposit or transfer alert landed. Pull the balance from the API rather
  /// than waiting for the next screen visit — the balance drives the card here
  /// and previously only changed on a cold refresh.
  void _onTransactionActivity() {
    if (!mounted) return;
    context.read<AuthBloc>().add(AuthRefreshUserRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BackToExitWrapper(child: _buildRootBody(context));
  }

  Widget _buildRootBody(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(theme),
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: theme.scaffoldBackgroundColor,
        drawer: const CooperativeSidebar(),
        drawerEdgeDragWidth: 50.w,
        drawerScrimColor: Colors.black.withValues(alpha: 0.4),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                HomeHeader(scaffoldKey: _scaffoldKey, theme: theme),

                vSpace(16),

                BlocBuilder<AuthBloc, AuthState>(
                  buildWhen: (prev, next) {
                    if (prev.runtimeType != next.runtimeType) return true;
                    if (prev is! AuthAuthenticated ||
                        next is! AuthAuthenticated) {
                      return true;
                    }
                    final a = prev.user;
                    final b = next.user;
                    String wan(UserModel u) =>
                        u.walletAccountNumber?.trim() ?? '';
                    return wan(a) != wan(b) ||
                        (a.communalTier ?? '') != (b.communalTier ?? '') ||
                        (a.kycWorkflowStatus ?? '') !=
                            (b.kycWorkflowStatus ?? '') ||
                        (a.kycStatus ?? '') != (b.kycStatus ?? '') ||
                        (a.kycRejectionReason ?? '') !=
                            (b.kycRejectionReason ?? '') ||
                        a.kycStep2Submitted != b.kycStep2Submitted ||
                        a.kycStep3Submitted != b.kycStep3Submitted;
                  },
                  builder: (context, authState) {
                    if (authState is AuthAuthenticated) {
                      final u = authState.user;
                      if (u.hasProvisionedWalletAccountNumber) {
                        return HomeAccountCardSection(user: u);
                      }
                      if (u.shouldShowHomeKycPendingWalletProvisioning) {
                        return const KycPendingApprovalCard();
                      }
                      if (u.isKycRejected) {
                        return KycAlert(
                          title: 'KYC NOT APPROVED',
                          message: u.kycRejectionMessage ??
                              'Your verification was not approved. Kindly review the '
                                  'details you submitted and try again.',
                        );
                      }
                    }
                    return const KycAlert();
                  },
                ),

                BlocBuilder<AuthBloc, AuthState>(
                  buildWhen: (prev, next) {
                    if (prev.runtimeType != next.runtimeType) return true;
                    if (prev is AuthAuthenticated &&
                        next is AuthAuthenticated) {
                      return prev.user.hasSecurityPin !=
                          next.user.hasSecurityPin;
                    }
                    return true;
                  },
                  builder: (context, authState) {
                    final showPin =
                        authState is AuthAuthenticated &&
                        authState.user.hasSecurityPin != true;
                    if (showPin) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          vSpace(10),
                          const PinSetupNoticeCard(),
                          vSpace(12),
                        ],
                      );
                    }
                    return vSpace(4);
                  },
                ),

                BlocBuilder<AuthBloc, AuthState>(
                  buildWhen: (prev, next) {
                    if (prev.runtimeType != next.runtimeType) return true;
                    if (prev is AuthAuthenticated &&
                        next is AuthAuthenticated) {
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

                vSpace(14),

                // Quick Actions
                QuickActionsSection(theme: theme),

                vSpace(24),

                // Recent Transactions
                const RecentTransactionsSection(),

                vSpace(20),

                // New Feature Banner
                NewFeatureBanner(theme: theme),

                vSpace(24),
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
