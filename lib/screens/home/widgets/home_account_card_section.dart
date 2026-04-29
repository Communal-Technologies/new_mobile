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

/// Inner balance banner uses a slightly brighter purple than the
/// brand primary so it visually layers on the outer card without
/// fighting it.
const Color _kBalanceBannerPurple = Color(0xFF9810FA);

/// Subtle "Copy Acc. No." chip background — `#C8A0FF` at 20% opacity.
/// Reads on the white outer card (light) and on the dark surface
/// (dark) without competing with the balance banner.
const Color _kCopyButtonBg = Color(0x33C8A0FF);

/// Home finance card: tabs (Savings / Investments / Loans) sit on top
/// of the card; the *selected* tab is painted in the same colour as
/// the outer card and overlaps its top edge by 1 logical pixel, so
/// visually the tab and the card join into a single shape (the
/// inactive tabs sit slightly lower with no fill, "behind" the card).
///
/// Inside the card a purple sub-banner shows the balance row; the
/// account name + number row + Copy CTA sit on the outer card surface
/// (theme.cardColor) below it. "Add Money" was removed per design
/// feedback — the action wasn't shipped and the dummy snackbar
/// shouldn't ride to production.
///
/// Shown when [UserModel.walletAccountNumber] is set (wallet
/// provisioned after KYC); otherwise home may show
/// [KycPendingApprovalCard] or [KycAlert].
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

    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FinanceTabsRow(
            tabIndex: _tabIndex,
            // Selected-tab fill matches the outer card surface so the
            // tab visually joins the card. On dark mode that's the
            // dark surface, on light mode it's white — same colour as
            // `cardSurface` below.
            cardSurface: theme.cardColor,
            primary: theme.primaryColor,
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
          // -1.h vertical shift so the selected tab overlaps the card
          // top edge by exactly one logical pixel — eliminates the
          // sub-pixel seam that otherwise shows up between the tab
          // and the card border.
          Transform.translate(
            offset: Offset(0, -1.h),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
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
          copyBg: _kCopyButtonBg,
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
    required this.cardSurface,
    required this.primary,
    required this.onChanged,
  });

  final int tabIndex;
  final Color cardSurface;
  final Color primary;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // Inactive tabs render directly on the scaffold (so their fill is
    // transparent). The selected tab gets the card's surface colour
    // and only the top corners rounded, so the bottom edge butts
    // flush against the card top — visually one continuous shape.
    final theme = Theme.of(context);
    final inactive = theme.colorScheme.onSurface.withValues(alpha: 0.6);
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
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(14.r)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding:
                      EdgeInsets.symmetric(vertical: 10.h, horizontal: 4.w),
                  decoration: BoxDecoration(
                    color: sel ? cardSurface : Colors.transparent,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(14.r)),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, -2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].icon,
                        size: 22.sp,
                        color: sel ? primary : inactive,
                      ),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight:
                                sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? primary : inactive,
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
    required this.copyBg,
  });

  final UserModel user;
  final bool balanceVisible;
  final Future<void> Function() onToggleBalance;
  final Color primary;
  final Color copyBg;

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
    final theme = Theme.of(context);
    final mutedOnSurface =
        theme.colorScheme.onSurface.withValues(alpha: 0.7);
    final balanceText = CurrencyFormatter.formatNairaFromKoboWithDecimals(
      user.walletBalanceKobo,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Inner purple balance banner. White text only — sits on
        // brand colour, so it's the same in both themes.
        DecoratedBox(
          decoration: BoxDecoration(
            color: _kBalanceBannerPurple,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
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
                        color: Colors.white.withValues(alpha: 0.92),
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
                        color: Colors.white.withValues(alpha: 0.92),
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
                    color: mutedOnSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(text: _accountLabel),
                    TextSpan(
                      text: '  |  ',
                      style: TextStyle(
                        color: theme.dividerColor,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextSpan(
                      text: _accountNo.isEmpty ? '—' : _accountNo,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: mutedOnSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            hSpace(8),
            Material(
              color: copyBg,
              borderRadius: BorderRadius.circular(10.r),
              child: InkWell(
                onTap: _accountNo.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: _accountNo),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Account number copied'),
                            ),
                          );
                        }
                      },
                borderRadius: BorderRadius.circular(10.r),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 18.sp, color: primary),
                      SizedBox(width: 6.w),
                      Text(
                        'Copy Acc. No.',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: primary,
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
          Icon(icon, size: 40.sp, color: primary.withValues(alpha: 0.35)),
          vSpace(12),
          Text(
            '$title — coming soon',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.sp,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
