import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/loan_application.dart';

class ActiveLoanCard extends StatelessWidget {
  const ActiveLoanCard({
    super.key,
    required this.loan,
    this.onViewDetails,
    this.onMakePayment,
  });

  final LoanApplication loan;
  final VoidCallback? onViewDetails;
  final VoidCallback? onMakePayment;

  Color get _statusColor {
    switch (loan.status) {
      case LoanStatus.approved:
        return const Color(0xFF1976D2);
      case LoanStatus.pending:
        return const Color(0xFFE67E22);
      case LoanStatus.declined:
        return const Color(0xFFE74C3C);
      case LoanStatus.cancelled:
        return Colors.grey;
      case LoanStatus.unknown:
        return Colors.grey;
    }
  }

  Color get _statusBg {
    switch (loan.status) {
      case LoanStatus.approved:
        return const Color(0xFFE3F2FD);
      case LoanStatus.pending:
        return const Color(0xFFFFF4E9);
      case LoanStatus.declined:
        return const Color(0xFFFDECEA);
      case LoanStatus.cancelled:
      case LoanStatus.unknown:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isApproved = loan.status == LoanStatus.approved;
    // In dark mode, a black drop shadow on a dark scaffold is
    // invisible — the card vanishes into the background. Use a 1px
    // outline tinted with the scheme's onSurface so the card lifts
    // off the scaffold the way the obligation / detail cards do.
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: isDark
            ? Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.10),
                width: 1,
              )
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.loanCode.isNotEmpty ? loan.loanCode : 'Loan',
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    vSpace(4),
                    Text(
                      loan.referenceId.isNotEmpty ? loan.referenceId : loan.id,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: _statusBg,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  loan.status.label,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          vSpace(16),
          if (isApproved) ...[
            Text(
              'Repayment Progress',
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            vSpace(8),
            Stack(
              children: [
                Container(
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: loan.repaymentProgress,
                  child: Container(
                    height: 8.h,
                    decoration: BoxDecoration(
                      // Orange brand accent for the loan area (matches
                      // LoanOfferCard / loan detail header). Was the
                      // app-wide purple primary, which made the loan
                      // section feel theme-mixed.
                      color: const Color(0xFFE67E22),
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                  ),
                ),
              ],
            ),
            vSpace(4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                loan.progressLabel,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
            vSpace(16),
          ],
          Row(
            children: [
              Expanded(
                child: _statColumn(context, 'Principal', loan.amountLabel),
              ),
              Expanded(
                child: _statColumn(
                  context,
                  isApproved ? 'Balance' : 'Status',
                  isApproved ? loan.balanceLabel : loan.status.label,
                  highlight: isApproved,
                ),
              ),
              Expanded(
                child: _statColumn(
                  context,
                  isApproved ? 'Monthly' : 'Applied',
                  isApproved ? loan.monthlyRepaymentLabel : loan.createdAtLabel,
                ),
              ),
            ],
          ),
          if (loan.dueDateLabel != null) ...[
            vSpace(8),
            Row(
              children: [
                Icon(Icons.event, size: 14.sp, color: Colors.grey.shade600),
                hSpace(6),
                Text(
                  'Due ${loan.dueDateLabel}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
          vSpace(16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewDetails,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                  child: Text(
                    'View Details',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              if (isApproved) ...[
                hSpace(12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onMakePayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE67E22),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                    ),
                    child: Text(
                      'Make Payment',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _statColumn(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade600),
        ),
        vSpace(4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: highlight
                ? const Color(0xFFE67E22)
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
