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
    final defaultIconColor = iconColor ?? const Color(0xFF7434FF);
    final isDisabled = !enabled;

    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: (isDisabled
                      ? Colors.grey.shade300
                      : defaultIconColor.withOpacity(0.1)),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              icon,
              color: isDisabled ? Colors.grey.shade400 : defaultIconColor,
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
                              ? Colors.grey.shade400
                              : const Color(0xFF0F1D40),
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
                    color: isDisabled
                        ? Colors.grey.shade400
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeThumbColor: const Color(0xFF7434FF),
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

