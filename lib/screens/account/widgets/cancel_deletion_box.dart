import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class CancelDeletionBox extends StatelessWidget {
  const CancelDeletionBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), // Light blue
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFF2196F3), // Blue
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24.w,
                height: 24.w,
                decoration: const BoxDecoration(
                  color: Color(0xFF2196F3), // Blue
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'i',
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              hSpace(12),
              Expanded(
                child: Text(
                  'Changed your mind?',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2196F3),
                  ),
                ),
              ),
            ],
          ),
          vSpace(8),
          Text(
            'You can cancel now and keep your account.',
            style: TextStyle(
              fontSize: 17.sp,
              color: const Color(0xFF2196F3),
              height: 1.5,
            ),
          ),
          vSpace(16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                // Navigate back to home/account settings
                // Pop all delete account screens
                while (context.canPop()) {
                  context.pop();
                }
                // If we're at root, navigate to account settings or home
                if (!context.canPop()) {
                  context.go('/');
                }
              },
              style: OutlinedButton.styleFrom(
                backgroundColor: Theme.of(context).cardColor,
                side: const BorderSide(
                  color: Color(0xFF2196F3),
                  width: 1.5,
                ),
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Cancel Deletion',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2196F3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

