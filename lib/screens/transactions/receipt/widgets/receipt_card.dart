import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';

import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';
import 'package:communal_mobile/screens/transactions/receipt/receipt_status_style.dart';

/// Audit M39: the receipt card body, broken out from the giant
/// `_ReceiptCard.build()` that used to be inline in
/// `transaction_receipt_screen.dart`. Each sub-section is a private
/// widget so the build tree reads top-to-bottom as: hero → header →
/// amount → divider → info table → footer-note.
///
/// The card is a pure function of [TransactionDetailsData] — no bloc
/// reads, no controllers — so it renders identically in tests and inside
/// `RepaintBoundary` for the PNG capture path.
class ReceiptCard extends StatelessWidget {
  const ReceiptCard({super.key, required this.details});

  final TransactionDetailsData details;

  @override
  Widget build(BuildContext context) {
    final style = ReceiptStatusStyle(
      status: details.status,
      failureReason: details.failureReason,
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ReceiptStatusHero(style: style),
          vSpace(18),
          _ReceiptCardHeader(headerTitle: style.cardHeaderTitle),
          vSpace(20),
          if (style.showHeroAmount) ...[
            Text(
              details.amountLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 36.sp,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            vSpace(12),
          ],
          _ReceiptAmountPill(
            amountLabel: details.amountLabel,
            gradient: style.amountPillGradient,
          ),
          vSpace(18),
          Divider(color: Colors.grey.shade200, thickness: 1),
          vSpace(20),
          _ReceiptInfoTable(details: details, statusLabel: style.statusLabel),
          vSpace(24),
          _ReceiptFooterNote(
            note: style.footerNote(details.note),
            background: style.footerInfoBackground,
            iconColor: style.footerInfoIconColor,
          ),
        ],
      ),
    );
  }
}

/// Hero icon + title + subtitle block at the top of the card.
class _ReceiptStatusHero extends StatelessWidget {
  const _ReceiptStatusHero({required this.style});
  final ReceiptStatusStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(
          alignment: Alignment.center,
          child: Container(
            width: 84.w,
            height: 84.w,
            decoration: BoxDecoration(
              color: style.heroBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(
              style.heroIcon,
              color: style.statusColor,
              size: 44.sp,
            ),
          ),
        ),
        vSpace(14),
        Text(
          style.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: style.statusColor,
          ),
        ),
        vSpace(6),
        Text(
          style.subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// Logo on the left, "Transaction Receipt" / "Transfer details" on the right.
class _ReceiptCardHeader extends StatelessWidget {
  const _ReceiptCardHeader({required this.headerTitle});
  final String headerTitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          Images.coloredLogo,
          height: 32.h,
          fit: BoxFit.contain,
        ),
        const Spacer(),
        Text(
          headerTitle,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// Coloured pill ("Transfer Amount" + amount text) in the
/// status-appropriate gradient.
class _ReceiptAmountPill extends StatelessWidget {
  const _ReceiptAmountPill({
    required this.amountLabel,
    required this.gradient,
  });

  final String amountLabel;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        children: [
          Text(
            'Transfer Amount',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          vSpace(4),
          Text(
            amountLabel,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Five label/value rows (Recipient / Bank / Reference / Date / Status).
class _ReceiptInfoTable extends StatelessWidget {
  const _ReceiptInfoTable({
    required this.details,
    required this.statusLabel,
  });

  final TransactionDetailsData details;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ReceiptInfoRow(
          label: 'Recipient',
          value: details.counterpartyName,
        ),
        vSpace(16),
        _ReceiptInfoRow(
          label: 'Bank Account',
          value: details.counterpartyBankLine,
        ),
        vSpace(16),
        _ReceiptInfoRow(
          label: 'Reference',
          value:
              details.reference.trim().isEmpty ? '—' : details.reference,
        ),
        vSpace(16),
        _ReceiptInfoRow(
          label: 'Date and Time',
          value: details.formattedDate,
        ),
        vSpace(16),
        _ReceiptInfoRow(label: 'Status', value: statusLabel),
      ],
    );
  }
}

/// Tinted info-circle box at the bottom of the card.
class _ReceiptFooterNote extends StatelessWidget {
  const _ReceiptFooterNote({
    required this.note,
    required this.background,
    required this.iconColor,
  });

  final String note;
  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.info_circle, size: 18.sp, color: iconColor),
          hSpace(10),
          Expanded(
            child: Text(
              note,
              style: TextStyle(
                fontSize: 12.5.sp,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptInfoRow extends StatelessWidget {
  const _ReceiptInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
