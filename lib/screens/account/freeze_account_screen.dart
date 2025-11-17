import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/freeze_account_header.dart';
import 'package:communal_mobile/screens/account/widgets/account_to_freeze_card.dart';
import 'package:communal_mobile/screens/account/widgets/freeze_consequences_section.dart';
import 'package:communal_mobile/screens/account/widgets/freeze_action_buttons.dart';

class FreezeAccountScreen extends StatelessWidget {
  const FreezeAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Freeze Account',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Container(
            margin: EdgeInsets.all(16.w),
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const FreezeAccountHeader(
                  icon: Icons.pause_circle_outline,
                  title: 'Are you sure you want to Freeze your Account?',
                  description:
                      'This will temporarily disable your account and block all transactions until you unfreeze it.',
                ),
                vSpace(32),
                const AccountToFreezeCard(),
                vSpace(32),
                const FreezeConsequencesSection(),
                vSpace(40),
                FreezeActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
