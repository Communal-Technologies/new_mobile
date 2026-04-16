import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class KycCurrentTierCard extends StatelessWidget {
  const KycCurrentTierCard({super.key});

  @override
  Widget build(BuildContext context) {
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
                    'Tier 3',
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  hSpace(12),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5A1FE6), // Slightly darker purple
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      'Current',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
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
                    'Tier',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ],
          ),
          vSpace(24),
          _buildLimitRow(
            label: 'Daily Transaction Limit',
            value: '₦5,000,000',
          ),
          vSpace(16),
          _buildLimitRow(
            label: 'Maximum Balance',
            value: '₦10,000,000',
          ),
          vSpace(24),
          _buildVerificationStatus(
            label: 'NIN',
            value: '**** *** 2217',
            isVerified: true,
          ),
          vSpace(12),
          _buildBvnVerificationButton(context),
          vSpace(16),
          _buildKycDetailsButton(context),
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
            fontSize: 13.sp,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
        vSpace(4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationStatus({
    required String label,
    required String value,
    required bool isVerified,
  }) {
    return Row(
      children: [
        Icon(
          Icons.check_circle,
          color: Colors.green.shade300,
          size: 20.sp,
        ),
        hSpace(8),
        Text(
          '$label $value',
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildBvnVerificationButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          // TODO: Navigate to BVN verification
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('BVN verification coming soon')),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'BVN',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            hSpace(4),
            Text(
              'Verify BVN',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            hSpace(4),
            Icon(Icons.arrow_forward, size: 16.sp),
          ],
        ),
      ),
    );
  }

  Widget _buildKycDetailsButton(BuildContext context) {
    return InkWell(
      onTap: () {
        // TODO: Show KYC details bottom sheet or navigate
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KYC details')),
        );
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'KYC Details',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down,
            color: Colors.white,
            size: 20.sp,
          ),
        ],
      ),
    );
  }
}

