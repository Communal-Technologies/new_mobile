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
    // second row. Invest and Buy Now Pay Later are hidden — see TODO
    // below.
    final authState = context.watch<AuthBloc>().state;
    final hasCooperative = authState is AuthAuthenticated
        ? authState.user.hasCooperativeMembership
        : false;

    final payBillsTile = QuickActionButton(
      icon: Icons.credit_card,
      label: 'Pay Bills',
      theme: theme,
      onTap: () => context.pushNamed('bills'),
    );

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
              color: theme.colorScheme.onSurface,
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
                onTap: () => context.pushNamed('bills-data'),
              ),
              hSpace(10),
              QuickActionButton(
                icon: Icons.phone,
                label: 'Airtime',
                theme: theme,
                onTap: () => context.pushNamed('bills-airtime'),
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
                payBillsTile,
            ],
          ),
          // Second row hosts Pay Bills for cooperative members only.
          // TODO: re-introduce Invest and Buy Now Pay Later tiles
          // once those features ship — until then, keep the surface
          // tight so we don't promise something the user can't tap.
          if (hasCooperative) ...[
            vSpace(10),
            Row(
              children: [
                payBillsTile,
                hSpace(10),
                Expanded(child: SizedBox.shrink()),
                hSpace(10),
                Expanded(child: SizedBox.shrink()),
                hSpace(10),
                Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
