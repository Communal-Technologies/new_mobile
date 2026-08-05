import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class ContactMethodCard extends StatelessWidget {
  const ContactMethodCard({
    super.key,
    required this.icon,
    required this.title,
    required this.contact,
  });

  final IconData icon;
  final String title;
  final String contact;

  void _handleContact(BuildContext context) {
    if (icon == Icons.email) {
      Clipboard.setData(ClipboardData(text: contact));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Email copied: $contact')),
      );
    } else if (icon == Icons.phone) {
      Clipboard.setData(ClipboardData(text: contact));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone number copied: $contact')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _handleContact(context),
      borderRadius: BorderRadius.circular(12.r),
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
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: const Color(0xFF7434FF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF7434FF),
                size: 24.sp,
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
                    contact,
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

