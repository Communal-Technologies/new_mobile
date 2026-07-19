import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/currency_formatter.dart';
import 'package:communal_mobile/data/local/home_wallet_prefs.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/data/models/loan_application.dart';
import 'package:communal_mobile/data/repositories/loan_repository.dart';
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

/// Home finance card: tabs (Savings / Investments / Loans) and the
/// content area share **one** rounded surface (no gap between tab strip
/// and body). The selected tab is painted in the card's surface colour
/// so its bottom edge merges into the body; inactive tabs sit on a
/// muted tint of the same surface so they still read as tabs (not as
/// the body). A short vertical hairline between cells preserves
/// segment clarity.
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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FinanceTabsRow(
                tabIndex: _tabIndex,
                cardSurface: theme.cardColor,
                primary: theme.primaryColor,
                onChanged: (i) => setState(() => _tabIndex = i),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 18.h),
                child: _buildTabBody(context, user),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody(BuildContext context, UserModel user) {
    switch (_tabIndex) {
      case 0:
        final isDark = Theme.of(context).brightness == Brightness.dark;
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
          // Copy chip: brand purple in light mode reads against the
          // soft-purple chip background; on dark it disappears, so
          // switch to white.
          copyForeground: isDark ? Colors.white : Theme.of(context).primaryColor,
          copyBg: _kCopyButtonBg,
        );
      default:
        return _LoansTabContent(user: user);
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
    // The whole tabs+body card is one ClipRRect; this row is the top
    // band. Selected cell uses [cardSurface] so its bottom edge flows
    // straight into the body (no seam). Inactive cells overlay a soft
    // tint of the same surface so they read as tabs without separating
    // from the card. Hairlines between cells keep segment clarity.
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final inactiveTint = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final inactiveLabel = isDark
        ? Colors.white
        : theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final hairline = theme.dividerColor;
    final items = <({IconData icon, String label})>[
      (icon: Icons.account_balance_wallet_outlined, label: 'Savings'),
      (icon: Icons.request_quote_rounded, label: 'Loans'),
    ];

    return SizedBox(
      height: 52.h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(items.length, (i) {
          final sel = tabIndex == i;
          return Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: sel ? cardSurface : inactiveTint,
                border: Border(
                  right: i < 2 && !sel && tabIndex != i + 1
                      ? BorderSide(color: hairline, width: 0.6)
                      : BorderSide.none,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged(i),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: 10.h,
                      horizontal: 4.w,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          items[i].icon,
                          size: 22.sp,
                          color: sel ? primary : inactiveLabel,
                        ),
                        SizedBox(width: 6.w),
                        Flexible(
                          child: Text(
                            items[i].label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 19.sp,
                              fontWeight:
                                  sel ? FontWeight.w700 : FontWeight.w500,
                              color: sel ? primary : inactiveLabel,
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
      ),
    );
  }
}

class _SavingsTabContent extends StatelessWidget {
  const _SavingsTabContent({
    required this.user,
    required this.balanceVisible,
    required this.onToggleBalance,
    required this.copyForeground,
    required this.copyBg,
  });

  final UserModel user;
  final bool balanceVisible;
  final Future<void> Function() onToggleBalance;
  /// Foreground (icon + label) of the Copy Acc. chip. Brand purple in
  /// light mode, white in dark mode (the soft-purple chip bg eats
  /// brand-purple text on a dark card).
  final Color copyForeground;
  final Color copyBg;

  String get _accountLabel {
    final wa = user.walletAccountName?.trim();
    if (wa != null && wa.isNotEmpty) return wa;
    final n = user.name.trim();
    return n.isNotEmpty ? n : 'Account';
  }

  /// Bank / virtual account from `wallets` — not the cooperative [UserModel.ledgerNumber].
  String get _accountNo => user.walletAccountNumber?.trim() ?? '';

  String get _bankName => user.walletBankName?.trim() ?? '';

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
                        fontSize: 17.sp,
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
                        size: 24.sp,
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
                if (balanceVisible && user.walletLedgerKobo > 0) ...[
                  vSpace(6),
                  _BalanceSubLine(
                    icon: Icons.account_balance_wallet_outlined,
                    label:
                        '${CurrencyFormatter.formatNairaFromKoboWithDecimals(user.walletLedgerKobo)} ledger',
                  ),
                ],
                if (balanceVisible && user.walletPendingKobo > 0) ...[
                  vSpace(6),
                  _BalanceSubLine(
                    icon: Icons.schedule_rounded,
                    label:
                        '${CurrencyFormatter.formatNairaFromKoboWithDecimals(user.walletPendingKobo)} pending',
                  ),
                ],
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
                    fontSize: 17.sp,
                    color: mutedOnSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    if (_bankName.isNotEmpty) ...[
                      TextSpan(
                        text: _bankName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: '  |  ',
                        style: TextStyle(
                          color: theme.dividerColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
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
                  padding: EdgeInsets.all(10.w),
                  child: Icon(Icons.copy_rounded,
                      size: 18.sp, color: copyForeground),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LoansTabContent extends StatefulWidget {
  const _LoansTabContent({required this.user});

  final UserModel user;

  @override
  State<_LoansTabContent> createState() => _LoansTabContentState();
}

class _LoansTabContentState extends State<_LoansTabContent> {
  bool _loading = true;
  List<LoanApplication> _active = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loans = await LoanRepository(getIt()).fetchMyLoans(widget.user);
      if (!mounted) return;
      setState(() {
        _active =
            loans.where((l) => l.status == LoanStatus.approved).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    if (_loading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 28.h),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalOutstanding =
        _active.fold<int>(0, (sum, l) => sum + l.balanceMinor);
    final balanceText =
        CurrencyFormatter.formatNairaFromKoboWithDecimals(totalOutstanding);
    LoanApplication? next;
    for (final l in _active) {
      if (l.dueDate == null) continue;
      if (next == null || l.dueDate!.isBefore(next.dueDate!)) next = l;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                Text(
                  'Outstanding loan balance',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
                vSpace(6),
                Text(
                  balanceText,
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
        vSpace(12),
        if (_active.isEmpty)
          Text(
            'You have no active loans.',
            style: TextStyle(
              fontSize: 16.sp,
              color: onSurface.withValues(alpha: 0.6),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: _meta(context, 'Active loans', '${_active.length}'),
              ),
              if (next?.dueDateLabel != null)
                Expanded(
                  child: _meta(context, 'Next due', next!.dueDateLabel!),
                ),
            ],
          ),
      ],
    );
  }

  Widget _meta(BuildContext context, String label, String value) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: onSurface.withValues(alpha: 0.6),
          ),
        ),
        vSpace(2),
        Text(
          value,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
        ),
      ],
    );
  }
}

class _BalanceSubLine extends StatelessWidget {
  const _BalanceSubLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15.sp, color: Colors.white.withValues(alpha: 0.85)),
        SizedBox(width: 5.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }
}
