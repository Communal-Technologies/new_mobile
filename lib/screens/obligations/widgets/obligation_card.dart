import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/obligation.dart';

class ObligationCard extends StatelessWidget {
  const ObligationCard({super.key, required this.obligation, this.onTap});

  final Obligation obligation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final mutedOnSurface = onSurface.withValues(alpha: 0.6);

    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8.w,
                  runSpacing: 4.h,
                  children: [
                    _buildTag(
                      obligation.category,
                      theme.primaryColor.withValues(alpha: 0.15),
                      theme.primaryColor,
                    ),
                    _buildTag(
                      obligation.status,
                      _statusBackground(obligation.status),
                      _statusColor(obligation.status),
                    ),
                  ],
                ),
                vSpace(12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        obligation.title,
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: mutedOnSurface,
                      size: 22.sp,
                    ),
                  ],
                ),
                vSpace(12),
                Row(
                  children: [
                    Text(
                      obligation.amountBreakdown,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: onSurface,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      obligation.progressLabel,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
                vSpace(8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.r),
                  child: LinearProgressIndicator(
                    value: obligation.progress.clamp(0, 1),
                    minHeight: 10.h,
                    backgroundColor: theme.dividerColor,
                    valueColor: AlwaysStoppedAnimation(theme.primaryColor),
                  ),
                ),
                if (obligation.fines.isNotEmpty) ...[
                  vSpace(10),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEF0),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: const Color(0xFFD7263D),
                          size: 16.sp,
                        ),
                        hSpace(6),
                        Expanded(
                          child: Text(
                            '${obligation.fines.first.amountLabel} — ${obligation.fines.first.description}',
                            style: TextStyle(
                              fontSize: 15.sp,
                              color: const Color(0xFFD7263D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                vSpace(12),
                Row(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16.sp,
                          color: mutedOnSurface,
                        ),
                        hSpace(6),
                        Text(
                          obligation.installmentsLabel,
                          style: TextStyle(
                            fontSize: 15.sp,
                            color: mutedOnSurface,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Equity is share-based, not date-bound — showing a
                    // "next due" date there is misleading, so we skip
                    // the calendar pill for that category.
                    if (obligation.category != 'Equity')
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 16.sp,
                            color: mutedOnSurface,
                          ),
                          hSpace(6),
                          Text(
                            'Due ${obligation.nextDueDateLabel}',
                            style: TextStyle(
                              fontSize: 15.sp,
                              color: mutedOnSurface,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          vSpace(8),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color bg, Color fg) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  Color _statusBackground(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFFE8F9F0);
      case 'overdue':
        return const Color(0xFFFFEEF0);
      default:
        return const Color(0xFFE8ECFF);
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF1AAE70);
      case 'overdue':
        return const Color(0xFFD7263D);
      default:
        return const Color(0xFF5B5CE2);
    }
  }
}
