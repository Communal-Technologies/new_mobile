import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/transactions/models/sample_transactions.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.item, this.onTap});

  final TransactionListItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: item.iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.iconColor, size: 24.sp),
            ),
            hSpace(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 19.sp,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                  ),
                  vSpace(4),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      fontSize: 19.sp,
                      color: onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              item.signedAmountLabel,
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: item.amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
