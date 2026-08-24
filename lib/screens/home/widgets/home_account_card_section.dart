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

/// Home wallet card, one rounded surface with nothing to choose between:
/// the Loans tab and the tab strip above it are gone, so the card opens
/// on the balance instead of asking which balance is wanted. Loans keep
/// their own destination in the bottom bar.
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
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 18.h),
            child: _buildWalletBody(context, user),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletBody(BuildContext context, UserModel user) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _WalletCardContent(
      user: user,
      balanceVisible: _balanceVisible,
      onToggleBalance: () async {
        final auth = context.read<AuthBloc>().state;
        final uid = auth is AuthAuthenticated ? auth.user.id : widget.user.id;
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
  }
}

class _WalletCardContent extends StatelessWidget {
  const _WalletCardContent({
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
