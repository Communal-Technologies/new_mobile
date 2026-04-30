import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class ResourceItem extends StatelessWidget {
  const ResourceItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // TODO: Navigate to resource
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Opening $title...')),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).dividerColor,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF7434FF),
                size: 20.sp,
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
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  vSpace(4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 17.sp,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}

