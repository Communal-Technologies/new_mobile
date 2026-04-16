import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/home/widgets/dot_indicator.dart';

class NewFeatureBanner extends StatelessWidget {
  final ThemeData theme;

  const NewFeatureBanner({
    super.key,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.primaryColor,
                  theme.primaryColor.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'New Feature',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                vSpace(16),
                Text(
                  'Boost Your\nSavings',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                vSpace(8),
                Text(
                  'Earn up to 15% interest on\nfixed deposits',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.white.withValues(alpha: 0.95),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          vSpace(12),
          // Carousel dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DotIndicator(isActive: false, theme: theme),
              hSpace(6),
              DotIndicator(isActive: true, theme: theme),
              hSpace(6),
              DotIndicator(isActive: false, theme: theme),
            ],
          ),
        ],
      ),
    );
  }
}

