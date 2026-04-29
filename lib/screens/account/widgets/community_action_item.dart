import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class CommunityActionItem extends StatelessWidget {
  const CommunityActionItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 1.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        color: Colors.white,
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 22.sp,
              ),
            ),
            hSpace(16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  vSpace(4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              size: 22.sp,
            ),
          ],
        ),
      ),
    );
  }
}
