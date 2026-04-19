import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/utils/currency_formatter.dart';

class KycTierInfoCard extends StatelessWidget {
  const KycTierInfoCard({
    super.key,
    required this.tier,
    required this.dailyLimitKobo,
    required this.maxBalanceKobo,
    required this.requirements,
    this.isCurrent = false,
  });

  final int tier;
  /// Amounts from API in kobo (1 NGN = 100 kobo).
  final int dailyLimitKobo;
  final int maxBalanceKobo;
  final List<String> requirements;
  final bool isCurrent;

  String _formatFromKobo(int kobo) {
    return CurrencyFormatter.formatNairaFromKobo(kobo);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tier $tier',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F1D40),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7434FF),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    'Current',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          vSpace(16),
          _buildLimitItem(
            label: 'Daily Transaction Limit',
            value: _formatFromKobo(dailyLimitKobo),
          ),
          vSpace(12),
          _buildLimitItem(
            label: 'Maximum Balance',
            value: _formatFromKobo(maxBalanceKobo),
          ),
          vSpace(16),
          Text(
            'Requirements:',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          vSpace(8),
          ...requirements.map((requirement) => _buildRequirementItem(requirement)),
        ],
      ),
    );
  }

  Widget _buildLimitItem({
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15.sp,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF7434FF),
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementItem(String requirement) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 7.h, right: 8.w),
            width: 4.w,
            height: 4.w,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              requirement,
              style: TextStyle(
                fontSize: 15.sp,
                height: 1.35,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

