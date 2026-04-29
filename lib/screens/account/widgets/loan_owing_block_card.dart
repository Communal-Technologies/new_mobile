import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/space.dart';

/// Renders the "you can't close your account while you owe a loan" tile
/// shown inline on the freeze / delete-account screens when the member's
/// outstanding loan balance is non-zero. Tapping the CTA jumps the user
/// to the Loans tab so they can clear the debt before retrying.
class LoanOwingBlockCard extends StatelessWidget {
  const LoanOwingBlockCard({
    super.key,
    required this.outstandingMinor,
    required this.currency,
  });

  final int outstandingMinor;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final amountLabel = Money(outstandingMinor, currency).format();

    final bg = isDark
        ? const Color(0xFFFFB3BA).withValues(alpha: 0.08)
        : const Color(0xFFFFF1F2);
    final border = isDark
        ? const Color(0xFFFFB3BA).withValues(alpha: 0.4)
        : const Color(0xFFFFB3BA);
    final accent = const Color(0xFFD7263D);

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.lock_outline, color: accent, size: 24.sp),
              ),
              hSpace(12),
              Expanded(
                child: Text(
                  'Outstanding loan blocks closure',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          vSpace(14),
          Text(
            'You currently owe $amountLabel on an active loan. '
            'Account freeze and deletion are disabled until the loan is fully repaid.',
            style: TextStyle(
              fontSize: 15.sp,
              height: 1.4,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          vSpace(16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.goNamed('loans'),
              icon: const Icon(Icons.payments_outlined),
              label: Text(
                'Repay Loan',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
