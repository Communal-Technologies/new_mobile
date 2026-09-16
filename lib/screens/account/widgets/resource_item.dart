import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/support_models.dart';
import 'package:communal_mobile/screens/account/widgets/social_media_section.dart';

class ResourceItem extends StatelessWidget {
  const ResourceItem({super.key, required this.link});

  final SupportLink link;

  IconData get _icon {
    switch (link.key) {
      case 'user_guide':
        return Icons.menu_book_outlined;
      case 'video_tutorials':
        return Icons.video_library_outlined;
      case 'privacy_policy':
        return Icons.privacy_tip_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openSupportLink(link),
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
                _icon,
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
                    link.label,
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (link.description.isNotEmpty) ...[
                    vSpace(4),
                    Text(
                      link.description,
                      style: TextStyle(
                        fontSize: 17.sp,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.open_in_new,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
              size: 18.sp,
            ),
          ],
        ),
      ),
    );
  }
}
