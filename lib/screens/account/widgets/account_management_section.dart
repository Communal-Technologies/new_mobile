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
              color: Theme.of(context).colorScheme.onSurface,
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
        // TODO(communal-mobile): wire Bank Card/Account once the
        // backend exposes linked-bank metadata. Hidden until then so
        // a non-functional row doesn't show a SnackBar stub.
        // SettingItem(
        //   icon: Icons.credit_card,
        //   title: 'Bank Card/Account',
        //   description: '2 linked cards/accounts',
        //   onTap: () {
        //     ScaffoldMessenger.of(context).showSnackBar(
        //       const SnackBar(content: Text('Bank Card/Account')),
        //     );
        //   },
        // ),
        SettingItem(
          icon: Icons.trending_up,
          title: 'Account Limits',
          description: 'View your transaction limits',
          onTap: () {
            context.pushNamed('account-limits');
          },
        ),
        // TODO(communal-mobile): Invite and Earn screen has hard-coded
        // referral copy and no backend integration yet. Hide until the
        // referrals service / payout rules ship.
        // SettingItem(
        //   icon: Icons.share,
        //   title: 'Invite and Earn',
        //   description: 'Invite friends and earn up to ₦5,000 Bonus',
        //   onTap: () {
        //     context.pushNamed('invite-and-earn');
        //   },
        // ),
      ],
    );
  }
}

