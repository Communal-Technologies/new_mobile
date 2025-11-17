import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/kyc_current_tier_card.dart';
import 'package:communal_mobile/screens/account/widgets/kyc_tier_info_card.dart';

class AccountLimitsScreen extends StatelessWidget {
  const AccountLimitsScreen({super.key});

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
            'KYC Levels',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              vSpace(16),
              const KycCurrentTierCard(),
              vSpace(24),
              _buildKycBenefitSection(),
              vSpace(16),
              const KycTierInfoCard(
                tier: 1,
                dailyLimit: 50000,
                maxBalance: 300000,
                requirements: ['Verify BVN or NIN'],
              ),
              vSpace(12),
              const KycTierInfoCard(
                tier: 2,
                dailyLimit: 200000,
                maxBalance: 1000000,
                requirements: [
                  'Verify BVN and NIN',
                  'Link bank account',
                ],
              ),
              vSpace(12),
              const KycTierInfoCard(
                tier: 3,
                dailyLimit: 5000000,
                maxBalance: 10000000,
                requirements: [
                  'Complete Tier 2',
                  'Upload valid ID',
                  'Address verification',
                ],
                isCurrent: true,
              ),
              vSpace(24),
              _buildUpgradeButton(context),
              vSpace(16),
              _buildRewardText(),
              vSpace(32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKycBenefitSection() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'KYC Level Benefit',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          vSpace(4),
          Text(
            'The higher the level, the higher the transaction limit',
            style: TextStyle(
              fontSize: 13.sp,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            // TODO: Navigate to verification/upgrade flow
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Upgrade flow coming soon')),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7434FF),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            elevation: 0,
          ),
          child: Text(
            'Verify to Upgrade',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardText() {
    return Center(
      child: Text(
        'Upgrade to Get your reward 🎁',
        style: TextStyle(
          fontSize: 13.sp,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }
}

