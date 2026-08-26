import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/support_models.dart';

/// The six entry points into the help desk.
///
/// Each card opens a conversation seeded with its own category, which is what
/// routes the ticket: the category picks the assistant's intent set, decides
/// which operators it can be assigned to on escalation, and is the label the
/// member sees on the request afterwards. Nothing is created until they write
/// something, so a card tapped by accident leaves no ticket behind.
class HelpCategoryGrid extends StatelessWidget {
  const HelpCategoryGrid({super.key});

  void _open(BuildContext context, String category, String title) {
    context.pushNamed(
      'support-chat',
      extra: <String, dynamic>{'category': category, 'categoryTitle': title},
    );
  }

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
            onTap: () => _open(context, SupportCategory.accountRegistration, 'Account Registration'),
          ),
          _HelpCategoryCard(
            icon: Icons.credit_card,
            title: 'Loan Issues',
            description: 'Application & repayment',
            iconColor: const Color(0xFF66BB6A), // Light green
            onTap: () => _open(context, SupportCategory.loans, 'Loan Issues'),
          ),
          _HelpCategoryCard(
            icon: Icons.people,
            title: 'Cooperative Problems',
            description: 'Community & contributions',
            iconColor: const Color(0xFFBA68C8), // Light purple
            onTap: () => _open(context, SupportCategory.cooperative, 'Cooperative Problems'),
          ),
          _HelpCategoryCard(
            icon: Icons.lock_open,
            title: 'Security Concerns',
            description: 'Account safety',
            iconColor: const Color(0xFFEF5350), // Light red
            onTap: () => _open(context, SupportCategory.security, 'Security Concerns'),
          ),
          _HelpCategoryCard(
            icon: Icons.phone_android,
            title: 'Transaction Issues',
            description: 'Payments & transfers',
            iconColor: const Color(0xFFFF9800), // Light orange
            onTap: () => _open(context, SupportCategory.transactions, 'Transaction Issues'),
          ),
          _HelpCategoryCard(
            icon: Icons.info_outline,
            title: 'Other Issues',
            description: 'General inquiries',
            iconColor: Colors.grey.shade600, // Light gray
            onTap: () => _open(context, SupportCategory.other, 'Other Issues'),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: (iconColor ?? const Color(0xFF7434FF))
                    .withValues(alpha: 0.1),
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
                    fontSize: 17.sp,
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
                    fontSize: 16.sp,
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

