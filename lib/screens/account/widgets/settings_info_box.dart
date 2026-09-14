import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

/// Footer notice: community settings are stored per cooperative and synced to your account.
class SettingsInfoBox extends StatelessWidget {
  const SettingsInfoBox({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF3A78D1).withValues(alpha: isDark ? 0.15 : 0.10),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFF3A78D1).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: const Color(0xFF00ACC1),
            size: 26.sp,
          ),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Per-cooperative settings',
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark
                          ? const Color(0xFF90CAF9)
                          : const Color(0xFF12427A),
                  ),
                ),
                vSpace(6),
                Text(
                  'Each switch applies only to the cooperative selected above. '
                  'Your choices are saved to your account and apply on this device when you are online.',
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: isDark
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85)
                    : const Color(0xFF1B3F6B),
                    height: 1.45,
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
