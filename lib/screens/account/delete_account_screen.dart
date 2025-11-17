import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/data_loss_item.dart';
import 'package:communal_mobile/screens/account/widgets/freeze_suggestion_box.dart';
import 'package:communal_mobile/screens/account/widgets/delete_account_warning_section.dart';
import 'package:communal_mobile/screens/account/widgets/delete_account_action_buttons.dart';

class DeleteAccountScreen extends StatelessWidget {
  const DeleteAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Delete Account',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      children: [
                        vSpace(32),
                        const DeleteAccountWarningSection(),
                        vSpace(32),
                        const _DataLossSection(),
                        vSpace(24),
                        const FreezeSuggestionBox(),
                        vSpace(32),
                      ],
                    ),
                  ),
                ),
              ),
              const DeleteAccountActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

}

class _DataLossSection extends StatelessWidget {
  const _DataLossSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Here\'s what you\'ll lose',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(16),
        const DataLossItem(
          icon: Icons.people,
          title: 'Cooperative Memberships',
          description: '2 active cooperative memberships will be lost',
          iconColor: Color(0xFFBA68C8), // Purple
        ),
        vSpace(12),
        const DataLossItem(
          icon: Icons.description,
          title: 'Transaction History',
          description: '156 transaction records will be permanently deleted',
          iconColor: Color(0xFF42A5F5), // Blue
        ),
        vSpace(12),
        const DataLossItem(
          icon: Icons.trending_up,
          title: 'Loan Records',
          description: 'All loan applications and repayment history will be erased',
          iconColor: Color(0xFF66BB6A), // Green
        ),
        vSpace(12),
        const DataLossItem(
          icon: Icons.shield_outlined,
          title: 'Account Balance',
          description: '₦450,000 must be withdrawn before deletion',
          iconColor: Colors.red,
        ),
      ],
    );
  }
}
