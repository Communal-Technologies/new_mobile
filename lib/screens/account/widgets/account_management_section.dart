import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/setting_item.dart';

class AccountManagementSection extends StatelessWidget {
  const AccountManagementSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Text(
            'Account Management',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
        ),
        vSpace(12),
        SettingItem(
          icon: Icons.account_balance_wallet,
          title: 'Transaction History',
          description: 'View and manage past transactions',
          onTap: () {
            context.pushNamed('transactions');
          },
        ),
        SettingItem(
          icon: Icons.credit_card,
          title: 'Bank Card/Account',
          description: '2 linked cards/accounts',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bank Card/Account')),
            );
          },
        ),
        SettingItem(
          icon: Icons.trending_up,
          title: 'Account Limits',
          description: 'View your transaction limits',
          onTap: () {
            context.pushNamed('account-limits');
          },
        ),
        SettingItem(
          icon: Icons.share,
          title: 'Invite and Earn',
          description: 'Invite friends and earn up to ₦5,000 Bonus',
          onTap: () {
            context.pushNamed('invite-and-earn');
          },
        ),
      ],
    );
  }
}

