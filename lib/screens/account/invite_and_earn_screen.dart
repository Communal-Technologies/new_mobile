import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/invite_referral_banner.dart';
import 'package:communal_mobile/screens/account/widgets/referral_stats_grid.dart';
import 'package:communal_mobile/screens/account/widgets/referral_code_section.dart';
import 'package:communal_mobile/screens/account/widgets/share_via_section.dart';
import 'package:communal_mobile/screens/account/widgets/how_it_works_section.dart';
import 'package:communal_mobile/screens/account/widgets/referral_history_section.dart';

class InviteAndEarnScreen extends StatelessWidget {
  const InviteAndEarnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Invite and Earn',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.edit, color: Colors.grey.shade400, size: 20.sp),
              onPressed: () {},
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              vSpace(16),
              const InviteReferralBanner(),
              vSpace(20),
              const ReferralStatsGrid(),
              vSpace(24),
              const ReferralCodeSection(),
              vSpace(24),
              const ShareViaSection(),
              vSpace(24),
              const HowItWorksSection(),
              vSpace(24),
              const ReferralHistorySection(),
              vSpace(32),
            ],
          ),
        ),
      ),
    );
  }
}





