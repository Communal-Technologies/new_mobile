import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/obligation.dart';

class ObligationPaymentSuccessScreen extends StatelessWidget {
  const ObligationPaymentSuccessScreen({
    super.key,
    required this.obligation,
    required this.amountMinor,
    required this.method,
    required this.reference,
    required this.date,
  });

  final Obligation obligation;

  /// Integer minor units of [obligation.currency] (e.g. kobo for NGN).
  final int amountMinor;
  final String method;
  final String reference;
  final DateTime date;

  String _paidToLine(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    if (auth is AuthAuthenticated) {
      final line = auth.user.cooperativeDisplayName.trim();
      if (line.isNotEmpty && line != '—') return line;
    }
    final id = obligation.cooperativeId.trim();
    if (id.isNotEmpty) return id;
    return 'your cooperative';
  }

  @override
  Widget build(BuildContext context) {
    final formattedAmount = Money(amountMinor, obligation.currency).format();
    final dateLabel = DateFormat('MMM dd, yyyy, hh:mm a').format(date);
    final paidTo = _paidToLine(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: Text(
          'Payment Successful',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
        child: Column(
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F8EF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: const Color(0xFF1AAE70),
                size: 44.sp,
              ),
            ),
            vSpace(16),
            Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            vSpace(6),
            Text(
              'Your obligation payment has been processed successfully',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
            ),
            vSpace(18),
            Text(
              formattedAmount,
              style: TextStyle(
                fontSize: 30.sp,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            vSpace(4),
            Text(
              'Paid to $paidTo',
              style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
            ),
            vSpace(24),
            _DetailsCard(
              obligation: obligation,
              amountLabel: formattedAmount,
              method: method,
              reference: reference,
              dateLabel: dateLabel,
            ),
            vSpace(24),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.download_rounded,
                    label: 'Download',
                    onTap: () => AppToast.success('Downloading receipt...'),
                  ),
                ),
                hSpace(12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onTap: () => AppToast.success('Sharing receipt...'),
                  ),
                ),
              ],
            ),
            vSpace(20),
            _NextStepsCard(),
            vSpace(24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.goNamed('obligations'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7434FF),
                  minimumSize: Size(double.infinity, 52.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.obligation,
    required this.amountLabel,
    required this.method,
    required this.reference,
    required this.dateLabel,
  });

  final Obligation obligation;
  final String amountLabel;
  final String method;
  final String reference;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22.r),
      ),
      child: Column(
        children: [
          _DetailRow(label: 'Obligation', value: obligation.title),
          _DetailRow(label: 'Type', value: obligation.category),
          _DetailRow(label: 'Amount', value: amountLabel),
          _DetailRow(label: 'Payment Method', value: method),
          _DetailRow(label: 'Reference', value: reference, isLink: true),
          _DetailRow(label: 'Date & Time', value: dateLabel),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLink = false,
  });

  final String label;
  final String value;
  final bool isLink;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15.sp, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: isLink ? const Color(0xFF7434FF) : Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 20.sp),
            hSpace(8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextStepsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE9F2FF),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20.sp),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "What's Next?",
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                vSpace(6),
                Text(
                  'Your payment will reflect in your obligation history within a few minutes. You can view all your payments in the obligation details.',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
