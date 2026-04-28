import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/home/widgets/quick_action_button.dart';

class QuickActionsSection extends StatelessWidget {
  final ThemeData theme;

  const QuickActionsSection({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    // Loan is a cooperative-only feature — drop it from the quick
    // actions grid for users with no cooperative attached, and keep
    // the row visually balanced by promoting "Pay Bills" up from the
    // second row.
    final authState = context.watch<AuthBloc>().state;
    final hasCooperative = authState is AuthAuthenticated
        ? authState.user.hasCooperativeMembership
        : false;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick actions',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          vSpace(14),
          // First row - 4 buttons
          Row(
            children: [
              QuickActionButton(
                icon: Icons.account_balance,
                label: 'Transfer',
                theme: theme,
                onTap: () => context.pushNamed('transfer'),
              ),
              hSpace(10),
              QuickActionButton(
                icon: Icons.phone_android,
                label: 'Buy Data',
                theme: theme,
              ),
              hSpace(10),
              QuickActionButton(
                icon: Icons.phone,
                label: 'Airtime',
                theme: theme,
              ),
              hSpace(10),
              if (hasCooperative)
                QuickActionButton(
                  icon: Icons.favorite_border,
                  label: 'Loan',
                  theme: theme,
                  onTap: () => context.pushNamed('loans'),
                )
              else
                QuickActionButton(
                  icon: Icons.credit_card,
                  label: 'Pay Bills',
                  theme: theme,
                ),
            ],
          ),
          vSpace(10),
          // Second row - 3 buttons (or 2 when Pay Bills was promoted up)
          Row(
            children: [
              QuickActionButton(
                icon: Icons.account_balance,
                label: 'Invest',
                theme: theme,
              ),
              hSpace(10),
              QuickActionButton(
                icon: Icons.account_balance,
                label: 'Buy Now, Pay Later',
                theme: theme,
              ),
              if (hasCooperative) ...[
                hSpace(10),
                QuickActionButton(
                  icon: Icons.credit_card,
                  label: 'Pay Bills',
                  theme: theme,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
