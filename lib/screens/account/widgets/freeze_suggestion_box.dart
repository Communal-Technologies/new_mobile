import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class FreezeSuggestionBox extends StatelessWidget {
  const FreezeSuggestionBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF2196F3).withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: const Color(0xFF2196F3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Consider Freezing Instead?',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF64B5F6)
                  : const Color(0xFF1565C0),
            ),
          ),
          vSpace(8),
          Text(
            'If you just need a break, consider freezing your account instead. You can unfreeze it anytime and keep all your data.',
            style: TextStyle(
              fontSize: 17.sp,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

