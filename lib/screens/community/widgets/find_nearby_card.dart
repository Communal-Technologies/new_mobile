import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class FindNearbyCard extends StatelessWidget {
  const FindNearbyCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          // Lavender CTA — keep the brand tint visible on dark mode
          // by mixing with the primary colour instead of the fixed
          // light pastel that washes out on a near-black scaffold.
          color: isDark
              ? theme.primaryColor.withValues(alpha: 0.16)
              : const Color(0xFFEDE5FF),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on_outlined,
              color: theme.primaryColor,
              size: 22.sp,
            ),
            hSpace(8),
            Text(
              'Find Nearby Communities',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? theme.colorScheme.onSurface
                    : const Color(0xFF4B3D8F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
