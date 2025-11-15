import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/obligations/data/sample_obligations.dart';

class ObligationDetailScreen extends StatelessWidget {
  const ObligationDetailScreen({super.key, required this.obligation});

  final Obligation obligation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _DetailAppBar(title: obligation.title),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SummaryCard(obligation: obligation),
                    vSpace(20),
                    _AboutSection(obligation: obligation),
                    if (obligation.fines.isNotEmpty) ...[
                      vSpace(20),
                      _FinesSection(fine: obligation.fines.first),
                    ],
                    vSpace(20),
                    _PaymentHistorySection(obligation: obligation),
                    vSpace(20),
                    _LoanPromoCard(note: obligation.infoNote),
                    vSpace(20),
                  ],
                ),
              ),
            ),
            _BottomActions(obligation: obligation, theme: theme),
          ],
        ),
      ),
    );
  }
}

class _DetailAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DetailAppBar({required this.title});

  final String title;

  @override
  Size get preferredSize => Size.fromHeight(64.h);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      centerTitle: true,
      title: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          vSpace(4),
          Text(
            'Total Lenders Forum',
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
          ),
        ],
      ),
      leading: IconButton(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back, color: Colors.black),
      ),
      actions: [
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.help_outline),
          color: Colors.grey.shade700,
        ),
        hSpace(8),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.obligation});

  final Obligation obligation;

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return const Color(0xFF1AAE70);
      case 'overdue':
        return const Color(0xFFD7263D);
      default:
        return const Color(0xFF52E1A2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(obligation.status);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        gradient: const LinearGradient(
          colors: [Color(0xFF7434FF), Color(0xFF5E2CD5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                      'Total Amount',
                      style: TextStyle(color: Colors.white70, fontSize: 13.sp),
                    ),
                    vSpace(4),
                    Text(
                      '₦${obligation.totalAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: obligation.status, color: statusColor),
            ],
          ),
          vSpace(16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AmountColumn(label: 'Paid', value: obligation.paidAmount),
              _AmountColumn(label: 'Balance', value: obligation.balance),
            ],
          ),
          vSpace(16),
          LinearProgressIndicator(
            value: obligation.progress.clamp(0, 1),
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
          vSpace(12),
          Row(
            children: [
              _Badge(
                label:
                    '${obligation.installmentsPaid} of ${obligation.totalInstallments}',
              ),
              const Spacer(),
              Text(
                'Next: ${obligation.nextDueDateLabel}',
                style: TextStyle(color: Colors.white, fontSize: 13.sp),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmountColumn extends StatelessWidget {
  const _AmountColumn({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.white70, fontSize: 13.sp),
        ),
        vSpace(4),
        Text(
          '₦${value.toStringAsFixed(0)}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.white, fontSize: 12.sp),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.obligation});

  final Obligation obligation;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'About This Obligation',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            obligation.description,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          vSpace(16),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Start Date',
                  value: obligation.startDateLabel,
                ),
              ),
              hSpace(16),
              Expanded(
                child: _InfoTile(
                  label: 'End Date',
                  value: obligation.endDateLabel,
                ),
              ),
            ],
          ),
          vSpace(12),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  label: 'Frequency',
                  value: obligation.frequency,
                ),
              ),
              hSpace(16),
              Expanded(
                child: _InfoTile(
                  label: 'Per Installment',
                  value: obligation.perInstallmentLabel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          vSpace(12),
          child,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
        ),
        vSpace(4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}

class _FinesSection extends StatelessWidget {
  const _FinesSection({required this.fine});

  final FineRecord fine;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Fines & Penalties',
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEF0),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: const Color(0xFFD7263D),
                  size: 18.sp,
                ),
                hSpace(8),
                Text(
                  fine.amountLabel,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFD7263D),
                  ),
                ),
                const Spacer(),
                _StatusChip(label: fine.status, color: const Color(0xFFD7263D)),
              ],
            ),
            vSpace(8),
            Text(
              fine.description,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
            ),
            vSpace(8),
            Text(
              'Type: ${fine.type}   ${fine.dateLabel}',
              style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentHistorySection extends StatelessWidget {
  const _PaymentHistorySection({required this.obligation});

  final Obligation obligation;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      title: 'Payment History',
      child: Column(
        children: [
          for (int i = 0; i < obligation.payments.length; i++) ...[
            _PaymentTile(record: obligation.payments[i]),
            if (i != obligation.payments.length - 1) vSpace(12),
          ],
          vSpace(12),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'View All (${obligation.payments.length})',
              style: TextStyle(
                fontSize: 13.sp,
                color: const Color(0xFF5B5CE2),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({required this.record});

  final PaymentRecord record;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: const Color(0xFF7B61FF), size: 22.sp),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                vSpace(4),
                Text(
                  '${record.dateLabel}  •  ${record.method}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  record.reference,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            record.amountLabel,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanPromoCard extends StatelessWidget {
  const _LoanPromoCard({this.note});

  final String? note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F2FF),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.trending_up, color: Color(0xFF5B5CE2)),
              ),
              hSpace(12),
              Text(
                'Need a Loan?',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F1D40),
                ),
              ),
            ],
          ),
          vSpace(12),
          Text(
            note ??
                'Your consistent payments qualify you for cooperative loans at competitive rates.',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
          ),
          vSpace(12),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B5CE2),
              minimumSize: Size(double.infinity, 48.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14.r),
              ),
            ),
            child: const Text('View Loan Options'),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.obligation, required this.theme});

  final Obligation obligation;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
        decoration: const BoxDecoration(color: Colors.white),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contacting admin...')),
                  );
                },
                icon: Icon(
                  Icons.chat_bubble_outline,
                  color: theme.primaryColor,
                  size: 20.sp,
                ),
                label: Text(
                  'Contact Admin',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 52.h),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
              ),
            ),
            hSpace(12),
            Expanded(
              child: ElevatedButton(
                onPressed: () =>
                    context.pushNamed('obligation-payment', extra: obligation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7434FF),
                  elevation: 0,
                  minimumSize: Size(double.infinity, 52.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
                child: Text(
                  'Pay Now',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
