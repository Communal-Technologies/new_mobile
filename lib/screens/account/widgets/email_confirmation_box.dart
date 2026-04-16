import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class EmailConfirmationBox extends StatelessWidget {
  const EmailConfirmationBox({
    super.key,
    required this.email,
  });

  final String email;

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
      child: Row(
        children: [
          Icon(
            Icons.email_outlined,
            color: const Color(0xFF2196F3),
            size: 24.sp,
          ),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'A confirmation email has been sent to',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: const Color(0xFF2196F3),
                  ),
                ),
                vSpace(4),
                Text(
                  email,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2196F3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

