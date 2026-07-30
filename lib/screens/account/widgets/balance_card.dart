import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/utils/currency_formatter.dart';
import 'package:communal_mobile/data/local/home_wallet_prefs.dart';
import 'package:communal_mobile/injection.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    required this.onWithdraw,
  });

  final int balance;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    // Use the shared HomeWalletPrefs notifier so toggling here mirrors
    // the home dashboard / profile-card visibility setting and survives
    // a navigation away from this screen.
    final prefs = getIt<HomeWalletPrefs>();
    final auth = context.watch<AuthBloc>().state;
    final uid = auth is AuthAuthenticated ? auth.user.id : '';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF7434FF),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: AnimatedBuilder(
        animation: prefs,
        builder: (context, _) {
          final visible = uid.isEmpty ? true : prefs.isBalanceVisible(uid);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Balance',
                    style: TextStyle(
                      fontSize: 17.sp,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  IconButton(
                    onPressed: uid.isEmpty
                        ? null
                        : () => prefs.setBalanceVisible(uid, !visible),
                    icon: Icon(
                      visible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              vSpace(8),
              Text(
                visible
                    ? CurrencyFormatter.formatNaira(balance)
                    : '••••••••••',
                style: TextStyle(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              vSpace(20),
              Center(
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onWithdraw,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(
                      // Closure flow sends users to /transfer rather than
                      // a non-existent withdrawal screen — moving the
                      // remaining balance to another account is the only
                      // valid pre-deletion action.
                      'Transfer Funds',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

