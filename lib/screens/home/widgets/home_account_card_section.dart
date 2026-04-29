import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/currency_formatter.dart';
import 'package:communal_mobile/data/local/home_wallet_prefs.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

/// Home finance card: tabs (Savings / Investments / Loans) sit above a white card;
/// the selected tab visually connects to the card. Shown when [UserModel.walletAccountNumber]
/// is set (wallet provisioned after KYC); otherwise home may show [KycPendingApprovalCard]
/// or [KycAlert].
class HomeAccountCardSection extends StatefulWidget {
  const HomeAccountCardSection({super.key, required this.user});

  final UserModel user;

  @override
  State<HomeAccountCardSection> createState() => _HomeAccountCardSectionState();
}

class _HomeAccountCardSectionState extends State<HomeAccountCardSection> {
  int _tabIndex = 0;
  bool _balanceVisible = true;
  late final HomeWalletPrefs _prefs;

  @override
  void initState() {
    super.initState();
    _prefs = getIt<HomeWalletPrefs>();
    // Subscribe so toggling visibility on the account-settings profile
    // card updates this dashboard card live (and vice versa).
    _prefs.addListener(_onPrefsChanged);
    _reloadBalanceVisibilityFromPrefs();
  }

  @override
  void didUpdateWidget(covariant HomeAccountCardSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.id != widget.user.id) {
      // User identity flipped (re-login or session takeover) — reload
      // the persisted preference for the new user AND tell Flutter to
      // rebuild, otherwise the toggle stays on whatever the previous
      // session had set.
      final uid = widget.user.id.trim();
      if (uid.isNotEmpty) {
        setState(() {
          _balanceVisible = _prefs.isBalanceVisible(uid);
        });
      }
    }
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefsChanged);
    super.dispose();
  }

  void _onPrefsChanged() {
    if (!mounted) return;
    final uid = widget.user.id.trim();
    if (uid.isEmpty) return;
    final visible = _prefs.isBalanceVisible(uid);
    if (visible != _balanceVisible) {
      setState(() => _balanceVisible = visible);
    }
  }

  void _reloadBalanceVisibilityFromPrefs() {
    final uid = widget.user.id.trim();
    if (uid.isEmpty) return;
    _balanceVisible = _prefs.isBalanceVisible(uid);
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user =
        authState is AuthAuthenticated ? authState.user : widget.user;

    final primary = Theme.of(context).primaryColor;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FinanceTabsRow(
            tabIndex: _tabIndex,
            primary: primary,
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
          Transform.translate(
            offset: Offset(0, -1.h),
            child: DecoratedBox(
              // Wallet card now uses the brand primary as its surface
              // (was cardColor white). Tabs, balance row, account info,
              // and copy CTA all sit on the same purple, with white
              // text/icons throughout — matches the rest of the
              // dashboard's purple chrome and stays legible in both
              // light and dark themes.
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 18.h),
                child: _buildTabBody(context, user),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBody(BuildContext context, UserModel user) {
    switch (_tabIndex) {
      case 0:
        return _SavingsTabContent(
          user: user,
          balanceVisible: _balanceVisible,
          onToggleBalance: () async {
            final auth = context.read<AuthBloc>().state;
            final uid = auth is AuthAuthenticated
                ? auth.user.id
                : widget.user.id;
            final next = !_balanceVisible;
            await getIt<HomeWalletPrefs>().setBalanceVisible(uid, next);
            if (mounted) setState(() => _balanceVisible = next);
          },
          primary: Theme.of(context).primaryColor,
        );
      case 1:
        return _PlaceholderTab(
          icon: Icons.trending_up_rounded,
          title: 'Investments',
          primary: Theme.of(context).primaryColor,
        );
      default:
        return _PlaceholderTab(
          icon: Icons.request_quote_rounded,
          title: 'Loans',
          primary: Theme.of(context).primaryColor,
        );
    }
  }
}

class _FinanceTabsRow extends StatelessWidget {
  const _FinanceTabsRow({
    required this.tabIndex,
    required this.primary,
    required this.onChanged,
  });

  final int tabIndex;
  final Color primary;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // Tabs sit on top of the purple wallet card. Active = white pill
    // with the brand purple text (so it visually clips into the card
    // edge); inactive = white labels at reduced opacity.
    final inactiveOnPurple = Colors.white.withValues(alpha: 0.7);
    final items = <({IconData icon, String label})>[
      (icon: Icons.account_balance_wallet_outlined, label: 'Savings'),
      (icon: Icons.trending_up_rounded, label: 'Investments'),
      (icon: Icons.request_quote_rounded, label: 'Loans'),
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final sel = tabIndex == i;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 3.w),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14.r)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
                  decoration: BoxDecoration(
                    color: sel ? primary : Colors.transparent,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(14.r),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].icon,
                        size: 22.sp,
                        color: sel ? Colors.white : inactiveOnPurple,
                      ),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? Colors.white : inactiveOnPurple,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _SavingsTabContent extends StatelessWidget {
  const _SavingsTabContent({
    required this.user,
    required this.balanceVisible,
    required this.onToggleBalance,
    required this.primary,
  });

  final UserModel user;
  final bool balanceVisible;
  final Future<void> Function() onToggleBalance;
  final Color primary;

  String get _accountLabel {
    final wa = user.walletAccountName?.trim();
    if (wa != null && wa.isNotEmpty) return wa;
    final n = user.name.trim();
    return n.isNotEmpty ? n : 'Account';
  }

  /// Bank / virtual account from `wallets` — not the cooperative [UserModel.ledgerNumber].
  String get _accountNo => user.walletAccountNumber?.trim() ?? '';

  @override
  Widget build(BuildContext context) {
    // The wallet card is now a single purple surface, so all body
    // text/icons sit on purple — render in white. Soft white tints
    // for the secondary lines (label, divider).
    final softWhite = Colors.white.withValues(alpha: 0.85);
    final balanceText = CurrencyFormatter.formatNairaFromKoboWithDecimals(
      user.walletBalanceKobo,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Balance row sits directly on the card (no inner sub-container
        // any more — the whole card is purple). Add Money button is
        // gone per design feedback; the action wasn't shipped and the
        // dummy snackbar shouldn't ride to production.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Total balance',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          color: softWhite,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: onToggleBalance,
                        behavior: HitTestBehavior.opaque,
                        child: Icon(
                          balanceVisible
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20.sp,
                          color: softWhite,
                        ),
                      ),
                    ],
                  ),
                  vSpace(6),
                  Text(
                    balanceVisible ? balanceText : '••••••',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        vSpace(14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: RichText(
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: softWhite,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(text: _accountLabel),
                    TextSpan(
                      text: '  |  ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextSpan(
                      text: _accountNo.isEmpty ? '—' : _accountNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            hSpace(8),
            Material(
              // Copy CTA: subtle white-on-purple chip — readable on the
              // purple card without competing with the balance value.
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10.r),
              child: InkWell(
                onTap: _accountNo.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(text: _accountNo));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Account number copied')),
                          );
                        }
                      },
                borderRadius: BorderRadius.circular(10.r),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 18.sp, color: Colors.white),
                      SizedBox(width: 6.w),
                      Text(
                        'Copy Acc. No.',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.primary,
  });

  final IconData icon;
  final String title;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28.h),
      child: Column(
        children: [
          // Placeholder tabs sit on the same purple wallet card as the
          // savings tab now, so render the icon + label in soft white.
          Icon(icon, size: 40.sp, color: Colors.white.withValues(alpha: 0.5)),
          vSpace(12),
          Text(
            '$title — coming soon',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.sp,
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
