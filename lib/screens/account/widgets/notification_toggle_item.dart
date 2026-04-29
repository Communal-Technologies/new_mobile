import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

enum NotificationTag {
  premium,
  recommended,
}

class NotificationToggleItem extends StatelessWidget {
  const NotificationToggleItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.iconColor,
    this.tag,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;
  final Color? iconColor;
  final NotificationTag? tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultIconColor = iconColor ?? theme.primaryColor;
    final isDisabled = !enabled;
    final disabledTone = theme.colorScheme.onSurface.withValues(alpha: 0.35);
    final mutedTone = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      color: theme.cardColor,
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: isDisabled
                  ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
                  : defaultIconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              icon,
              color: isDisabled ? disabledTone : defaultIconColor,
              size: 20.sp,
            ),
          ),
          hSpace(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                          color: isDisabled
                              ? disabledTone
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (tag != null) ...[
                      hSpace(8),
                      _buildTag(tag!),
                    ],
                  ],
                ),
                vSpace(4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: isDisabled ? disabledTone : mutedTone,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: theme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildTag(NotificationTag tag) {
    final isPremium = tag == NotificationTag.premium;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: isPremium
            ? Colors.yellow.shade100
            : Colors.red.shade50,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        isPremium ? 'Premium' : 'Recommended',
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w600,
          color: isPremium
              ? Colors.orange.shade700
              : Colors.red.shade700,
        ),
      ),
    );
  }
}

