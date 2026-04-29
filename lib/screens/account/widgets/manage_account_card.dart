import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class ManageAccountCard extends StatelessWidget {
  const ManageAccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      // Tightened from EdgeInsets.all(20) — the section was reading
      // too airy next to the Personal Information / Address cards.
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        // Reads card colour from the live theme so the surface flips
        // alongside the dark/light toggle.
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.settings_outlined,
                color: const Color(0xFF7434FF),
                size: 20.sp,
              ),
              hSpace(8),
              Text(
                'Manage Account',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          vSpace(12),
          _ManageAccountItem(
            icon: Icons.pause_circle_outline,
            iconColor: const Color(0xFF1976D2),
            title: 'Freeze Account',
            badge: 'Temporary',
            badgeColor: const Color(0xFFE3F2FD),
            description: 'Temporarily disable your account. You can unfreeze it anytime.',
            onTap: () {
              context.pushNamed('freeze-account');
            },
          ),
          vSpace(10),
          _ManageAccountItem(
            icon: Icons.delete_outline,
            iconColor: const Color(0xFFD32F2F),
            title: 'Delete Account',
            badge: 'Permanent',
            badgeColor: const Color(0xFFFFEBEE),
            description: 'Permanently delete your account and all associated data.',
            onTap: () {
              context.pushNamed('delete-account');
            },
          ),
        ],
      ),
    );
  }
}

class _ManageAccountItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String badge;
  final Color badgeColor;
  final String description;
  final VoidCallback onTap;

  const _ManageAccountItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.badge,
    required this.badgeColor,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: iconColor,
              size: 22.sp,
            ),
            hSpace(10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                      hSpace(8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: iconColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  vSpace(6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: onSurface.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            hSpace(8),
            Icon(
              Icons.chevron_right,
              color: onSurface.withValues(alpha: 0.5),
              size: 20.sp,
            ),
          ],
        ),
      ),
    );
  }
}

