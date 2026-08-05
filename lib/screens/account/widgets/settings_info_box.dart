import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

/// Footer notice: community settings are stored per cooperative and synced to your account.
class SettingsInfoBox extends StatelessWidget {
  const SettingsInfoBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F7FA),
        borderRadius: BorderRadius.circular(12.r),
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
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                vSpace(6),
                Text(
                  'Each switch applies only to the cooperative selected above. '
                  'Your choices are saved to your account and apply on this device when you are online.',
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
