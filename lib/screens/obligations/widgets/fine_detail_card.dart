import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/obligation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// Shared fine card — used on the Fines tab, the obligation Fine Details
/// breakdown, and (in summary form) the obligation detail screen, so fines
/// look identical everywhere.
class FineDetailCard extends StatelessWidget {
  const FineDetailCard({
    super.key,
    required this.fine,
    required this.cooperativeId,
    this.onTap,
    this.amountMinorOverride,
    this.subtitleOverride,
  });

  final FineRecord fine;
  final String cooperativeId;

  /// When set, the whole card is tappable (summary mode) and the per-fine
  /// "Pay Fine" button is replaced by a "View breakdown" affordance.
  final VoidCallback? onTap;

  /// Summary mode: show this summed amount instead of the single fine's amount.
  final int? amountMinorOverride;

  /// Summary mode: show this instead of the fine description.
  final String? subtitleOverride;

  static const Color _accent = Color(0xFFD7263D);

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return const Color(0xFF1AAE70);
      case 'waived':
        return const Color(0xFF5B5CE2);
      case 'cancelled':
        return Colors.grey;
      default:
        return _accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _statusColor(fine.status);
    final amountLabel = amountMinorOverride != null
        ? Money(amountMinorOverride!, fine.currency).format()
        : fine.amountLabel;
    final subtitle = subtitleOverride ??
        (fine.description.isNotEmpty ? fine.description : 'Late payment fine');

    final card = Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark
              ? _accent.withValues(alpha: 0.25)
              : const Color(0xFFFFCDD3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isDark
                      ? _accent.withValues(alpha: 0.16)
                      : const Color(0xFFFFEEF0),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  fine.type,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: _accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  fine.status,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          vSpace(10),
          Text(
            amountLabel,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: _accent,
            ),
          ),
          vSpace(6),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 17.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          vSpace(6),
          Text(
            // The subtitle/description already carries the cycle the fine is
            // for ("…cycle due May 30"); label this one as when the fine was
            // raised so the two dates aren't ambiguous.
            'Issued ${fine.dateLabel}',
            style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade500),
          ),
          // Summary mode: tap the whole card to see the breakdown.
          if (onTap != null) ...[
            vSpace(10),
            Row(
              children: [
                Text(
                  'View breakdown',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: _accent,
                  ),
                ),
                Icon(Icons.chevron_right, color: _accent, size: 18.sp),
              ],
            ),
          ] else if (fine.isPending && fine.id.isNotEmpty) ...[
            vSpace(10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.pushNamed(
                  'fine-payment',
                  extra: {'fine': fine, 'cooperativeId': cooperativeId},
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 40.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                ),
                child: Text(
                  'Pay Fine',
                  style:
                      TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(16.r),
      onTap: onTap,
      child: card,
    );
  }
}
