import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class SupportHoursCard extends StatelessWidget {
  const SupportHoursCard({super.key});

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
          Text(
            'Support Hours',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          vSpace(16),
          _buildHoursRow('Monday - Friday', '8:00 AM - 8:00 PM WAT'),
          vSpace(12),
          _buildHoursRow('Saturday', '9:00 AM - 5:00 PM WAT'),
          vSpace(12),
          _buildHoursRow('Sunday', 'Closed'),
          vSpace(16),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.email,
                  color: Colors.white,
                  size: 16.sp,
                ),
                hSpace(8),
                Expanded(
                  child: Text(
                    'Email support available 24/7 with response within 24 hours',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoursRow(String day, String time) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          day,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 17.sp,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }
}

