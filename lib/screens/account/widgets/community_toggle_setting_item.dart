import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class CommunityToggleSettingItem extends StatelessWidget {
  const CommunityToggleSettingItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final mutedTone = onSurface.withValues(alpha: 0.6);
    final disabledTone = onSurface.withValues(alpha: 0.35);
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
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              icon,
              color: enabled
                  ? (value ? theme.primaryColor : mutedTone)
                  : disabledTone,
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
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w600,
                    color: enabled ? onSurface : disabledTone,
                  ),
                ),
                vSpace(4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: enabled ? mutedTone : disabledTone,
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
}
