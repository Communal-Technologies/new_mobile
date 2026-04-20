import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/currency_formatter.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

/// Balance row (Total balance + amount + Add Money).
const Color _kBalanceCardPurple = Color(0xFF9810FA);

/// Copy Acc. No. control background: `#C8A0FF` at **20%** opacity (on white card).
const Color _kCopyButtonBg = Color(0x33C8A0FF);

/// Home finance card: tabs (Savings / Investments / Loans) sit above a white card;
/// the selected tab visually connects to the card. Shown when [UserModel.walletAccountNumber]
/// is set (wallet provisioned after KYC); otherwise home shows [KycAlert].
class HomeAccountCardSection extends StatefulWidget {
  const HomeAccountCardSection({super.key, required this.user});

  final UserModel user;

  @override
  State<HomeAccountCardSection> createState() => _HomeAccountCardSectionState();
}

class _HomeAccountCardSectionState extends State<HomeAccountCardSection> {
  int _tabIndex = 0;
  bool _balanceVisible = true;

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user =
        authState is AuthAuthenticated ? authState.user : widget.user;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FinanceTabsRow(
            tabIndex: _tabIndex,
            primary: Theme.of(context).primaryColor,
            onChanged: (i) => setState(() => _tabIndex = i),
          ),
          Transform.translate(
            offset: Offset(0, -1.h),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
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
          onToggleBalance: () => setState(() => _balanceVisible = !_balanceVisible),
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
    required this.primary,
    required this.onChanged,
  });

  final int tabIndex;
  final Color primary;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
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
                    color: sel ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(14.r),
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
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
                        size: 20.sp,
                        color: sel ? primary : Colors.grey.shade600,
                      ),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          items[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                            color: sel ? primary : Colors.grey.shade600,
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
  final VoidCallback onToggleBalance;
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
    final balanceText =
        CurrencyFormatter.formatNairaFromKobo(user.walletBalanceKobo);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: _kBalanceCardPurple,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 12.w, 14.h),
            child: Row(
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
                              fontSize: 13.sp,
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
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 90.07.w,
                  height: 37.7.h,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    elevation: 0,
                    child: InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Add money — coming soon')),
                        );
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Center(
                        child: Text(
                          'Add Money',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                      ),
                    ),
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
                    fontSize: 14.sp,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  children: [
                    TextSpan(text: _accountLabel),
                    TextSpan(
                      text: '  |  ',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    TextSpan(
                      text: _accountNo.isEmpty ? '—' : _accountNo,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade700,
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
                      Icon(Icons.copy_rounded, size: 18.sp, color: primary),
                      SizedBox(width: 6.w),
                      Text(
                        'Copy Acc. No.',
                        style: TextStyle(
                          fontSize: 12.sp,
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
              fontSize: 14.sp,
              color: Colors.grey.shade600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
