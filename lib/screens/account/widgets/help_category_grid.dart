import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class HelpCategoryGrid extends StatelessWidget {
  const HelpCategoryGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12.h,
        crossAxisSpacing: 12.w,
        childAspectRatio: 1.15,
        children: [
          _HelpCategoryCard(
            icon: Icons.person,
            title: 'Account Registration',
            description: 'Sign up issues',
            iconColor: const Color(0xFF4FC3F7), // Light blue
            onTap: () {
              // TODO: Navigate to account registration help
            },
          ),
          _HelpCategoryCard(
            icon: Icons.credit_card,
            title: 'Loan Issues',
            description: 'Application & repayment',
            iconColor: const Color(0xFF66BB6A), // Light green
            onTap: () {
              // TODO: Navigate to loan issues help
            },
          ),
          _HelpCategoryCard(
            icon: Icons.people,
            title: 'Cooperative Problems',
            description: 'Community & contributions',
            iconColor: const Color(0xFFBA68C8), // Light purple
            onTap: () {
              // TODO: Navigate to cooperative problems help
            },
          ),
          _HelpCategoryCard(
            icon: Icons.lock_open,
            title: 'Security Concerns',
            description: 'Account safety',
            iconColor: const Color(0xFFEF5350), // Light red
            onTap: () {
              // TODO: Navigate to security concerns help
            },
          ),
          _HelpCategoryCard(
            icon: Icons.phone_android,
            title: 'Transaction Issues',
            description: 'Payments & transfers',
            iconColor: const Color(0xFFFF9800), // Light orange
            onTap: () {
              // TODO: Navigate to transaction issues help
            },
          ),
          _HelpCategoryCard(
            icon: Icons.info_outline,
            title: 'Other Issues',
            description: 'General inquiries',
            iconColor: Colors.grey.shade600, // Light gray
            onTap: () {
              // TODO: Navigate to other issues help
            },
          ),
        ],
      ),
    );
  }
}

class _HelpCategoryCard extends StatelessWidget {
  const _HelpCategoryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: (iconColor ?? const Color(0xFF7434FF)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(
                icon,
                color: iconColor ?? const Color(0xFF7434FF),
                size: 20.sp,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                vSpace(4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

