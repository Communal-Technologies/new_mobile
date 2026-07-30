import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class InviteReferralBanner extends StatelessWidget {
  const InviteReferralBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: const Color(0xFF7434FF),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Icon(
            Icons.card_giftcard,
            color: Colors.white,
            size: 50.sp,
          ),
          vSpace(16),
          Text(
            'Invite Friends & Earn',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          vSpace(8),
          Text(
            'Earn up to ₦5,000 for every friend who signs up and completes their first transaction',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17.sp,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}





