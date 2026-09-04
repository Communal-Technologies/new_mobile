import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class FinalWarningBox extends StatelessWidget {
  const FinalWarningBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE), // Light red
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFFD32F2F), // Red
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are You Absolutely Sure?',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFD32F2F),
            ),
          ),
          vSpace(8),
          Text(
            'The next step asks for your PIN, and your account is closed the '
            'moment it is accepted. Your personal data is then erased within 30 '
            'days. This cannot be reversed.',
            style: TextStyle(
              fontSize: 17.sp,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

