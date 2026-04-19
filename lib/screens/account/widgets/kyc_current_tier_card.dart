import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/utils/currency_formatter.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/tier_limits_model.dart';

/// Summary of the member's Communal KYC tier and limits (amounts from API in kobo).
class KycCurrentTierCard extends StatelessWidget {
  const KycCurrentTierCard({
    super.key,
    required this.current,
    this.nextTierKey,
    this.onContinueVerification,
  });

  final TierCurrent current;
  final String? nextTierKey;
  final VoidCallback? onContinueVerification;

  @override
  Widget build(BuildContext context) {
    final title = current.displayTierTitle;
    final showUpgrade = nextTierKey != null && onContinueVerification != null;
    final showCurrentBadge =
        current.tierKey == 'tier_1' || current.tierKey == 'tier_2';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF7434FF),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (showCurrentBadge) ...[
                    hSpace(12),
                    Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5A1FE6),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                  vSpace(4),
                  Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          vSpace(8),
          Text(
            current.label,
            style: TextStyle(
              fontSize: 15.sp,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
          vSpace(20),
          if (current.isPreVerificationTier) ...[
            Text(
              'You are not on a verification tier yet. Complete profile and bank '
              'verification to get your account number and Tier 1 limits.',
              style: TextStyle(
                fontSize: 16.sp,
                height: 1.35,
                color: Colors.white.withOpacity(0.92),
              ),
            ),
          ] else ...[
            _buildLimitRow(
              label: 'Daily transaction limit',
              value: CurrencyFormatter.formatNairaFromKobo(
                current.dailyTransactionLimitKobo,
              ),
            ),
            vSpace(16),
            _buildLimitRow(
              label: 'Maximum balance',
              value: CurrencyFormatter.formatNairaFromKobo(
                current.maxBalanceKobo,
              ),
            ),
          ],
          if (showUpgrade) ...[
            vSpace(20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onContinueVerification,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withOpacity(0.35),
                    width: 1.5,
                  ),
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                ),
                child: Text(
                  nextTierKey == 'tier_2'
                      ? 'Continue to Tier 2 verification'
                      : 'Continue verification',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLimitRow({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15.sp,
            color: Colors.white.withOpacity(0.82),
          ),
        ),
        vSpace(4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
