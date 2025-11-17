import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class FeedbackInfoBox extends StatelessWidget {
  const FeedbackInfoBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), // Light blue
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          hSpace(12),
          Expanded(
            child: Text(
              'Your feedback helps us improve our services for everyone. Thank you for sharing.',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

