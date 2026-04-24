import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/home/widgets/quick_action_button.dart';

class QuickActionsSection extends StatelessWidget {
  final ThemeData theme;

  const QuickActionsSection({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick actions',
            style: TextStyle(
              fontSize: 20.sp,
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
              QuickActionButton(
                icon: Icons.favorite_border,
                label: 'Loan',
                theme: theme,
              ),
            ],
          ),
          vSpace(10),
          // Second row - 3 buttons
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
              hSpace(10),
              QuickActionButton(
                icon: Icons.credit_card,
                label: 'Pay Bills',
                theme: theme,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
