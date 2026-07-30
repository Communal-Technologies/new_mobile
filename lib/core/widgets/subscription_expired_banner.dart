import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';

/// A persistent amber banner shown on cooperative action screens when the
/// member's subscription has expired. The banner blocks action buttons below
/// while still letting the member read their data.
class SubscriptionExpiredBanner extends StatelessWidget {
  const SubscriptionExpiredBanner({super.key, this.endDate});

  /// The expiry date string from the API (e.g. "2026-04-30"). Shown when
  /// non-null so the member knows when it expired.
  final String? endDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF3D2600)
            : const Color(0xFFFFF3CD),
        border: Border.all(
          color: isDark
              ? const Color(0xFF7D4E00)
              : const Color(0xFFFFD466),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Iconsax.warning_2,
            size: 20.w,
            color: const Color(0xFFD97706),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subscription expired',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFFFD466)
                        : const Color(0xFF92400E),
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  endDate != null
                      ? 'Your cooperative subscription expired on $endDate. '
                          'Please contact your cooperative administrator to renew it.'
                      : 'Your cooperative subscription is inactive. '
                          'Please contact your cooperative administrator to renew it.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark
                        ? const Color(0xFFFFD466).withValues(alpha: 0.85)
                        : const Color(0xFF78350F),
                    height: 1.4,
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
