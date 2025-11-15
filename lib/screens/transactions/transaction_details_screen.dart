import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';

class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen({super.key, required this.details});

  final TransactionDetailsData details;
  static const String _receiptDownloadAction = 'download';
  static const String _receiptShareAction = 'share';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black87, size: 22.sp),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Transaction Details',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 32.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(theme),
                vSpace(16),
                _buildDetailsCard(theme),
                if (details.note != null) ...[
                  vSpace(16),
                  _buildNoteCard(theme),
                ],
                vSpace(24),
                _buildActionsSection(theme),
                vSpace(40),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 16.h),
            child: Row(
              children: [
                Expanded(
                  child: _BottomCtaButton(
                    label: 'Download',
                    icon: Iconsax.import,
                    backgroundColor: const Color(0xFFF0E6FF),
                    foregroundColor: theme.primaryColor,
                    onTap: () => _openReceipt(context, _receiptDownloadAction),
                  ),
                ),
                hSpace(12),
                Expanded(
                  child: _BottomCtaButton(
                    label: 'Share',
                    icon: Iconsax.export_1,
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    onTap: () => _openReceipt(context, _receiptShareAction),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openReceipt(BuildContext context, String action) {
    context.pushNamed(
      'transaction-receipt',
      extra: {'details': details, 'action': action},
    );
  }

  Widget _buildSummaryCard(ThemeData theme) {
    final statusColor = _statusColor(details.status, theme);
    final statusBackground = _statusBackgroundColor(details.status);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              _BankAvatar(
                bankLogoAsset: details.bankLogoAsset,
                initials: details.counterpartyBank.isNotEmpty
                    ? details.counterpartyBank.characters
                          .take(2)
                          .join()
                          .toUpperCase()
                    : 'BK',
              ),
              hSpace(12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details.counterpartLabel,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    vSpace(4),
                    Text(
                      details.counterpartyName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          vSpace(20),
          Text(
            details.amountLabel,
            style: TextStyle(
              fontSize: 34.sp,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
          vSpace(12),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _statusIcon(details.status),
                  size: 16.sp,
                  color: statusColor,
                ),
                hSpace(6),
                Text(
                  _statusLabel(details.status),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(ThemeData theme) {
    final infoRows = [
      _InfoRowData(label: 'Fees', value: details.feesLabel),
      _InfoRowData(
        label: details.isIncoming ? 'Sender Details' : 'Recipient Details',
        value: '${details.counterpartyName}\n${details.counterpartyBankLine}',
        isMultiline: true,
      ),
      _InfoRowData(label: 'Transaction Type', value: details.transactionType),
      _InfoRowData(label: 'Date and Time', value: details.formattedDate),
      _InfoRowData(label: 'Session ID', value: details.sessionId),
      _InfoRowData(label: 'Description', value: details.description),
      _InfoRowData(label: 'Transaction Reference', value: details.reference),
      _InfoRowData(label: 'Payment Method', value: details.paymentMethod),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 22.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        children: [
          for (int i = 0; i < infoRows.length; i++) ...[
            _TransactionInfoRow(data: infoRows[i]),
            if (i != infoRows.length - 1) ...[
              vSpace(16),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
              vSpace(16),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildNoteCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFBF5),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.info_circle, color: theme.primaryColor, size: 20.sp),
          hSpace(12),
          Expanded(
            child: Text(
              details.note!,
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(ThemeData theme) {
    final actions = [
      _ActionButtonData(
        label: 'Report',
        icon: Iconsax.warning_2,
        backgroundColor: const Color(0xFFFFEEF0),
        borderColor: const Color(0xFFFFD4DB),
        textColor: const Color(0xFFD7263D),
      ),
      _ActionButtonData(
        label: 'View Records',
        icon: Iconsax.document_text5,
        backgroundColor: const Color(0xFFF6F6F8),
        borderColor: const Color(0xFFE4E4E7),
        textColor: Colors.black87,
      ),
      _ActionButtonData(
        label: 'Transfer Again',
        icon: Iconsax.rotate_left,
        backgroundColor: const Color(0xFFF6F6F8),
        borderColor: const Color(0xFFE4E4E7),
        textColor: Colors.black87,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More actions',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        vSpace(12),
        Row(
          children: [
            for (int i = 0; i < actions.length; i++) ...[
              if (i != 0) hSpace(12),
              Expanded(child: _ActionButton(data: actions[i])),
            ],
          ],
        ),
      ],
    );
  }

  String _statusLabel(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.successful:
        return 'Successful';
    }
  }

  IconData _statusIcon(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return Iconsax.clock;
      case TransactionStatus.failed:
        return Iconsax.close_circle;
      case TransactionStatus.successful:
        return Iconsax.tick_circle;
    }
  }

  Color _statusColor(TransactionStatus status, ThemeData theme) {
    switch (status) {
      case TransactionStatus.pending:
        return const Color(0xFFE6A502);
      case TransactionStatus.failed:
        return const Color(0xFFD7263D);
      case TransactionStatus.successful:
        return const Color(0xFF1AAE70);
    }
  }

  Color _statusBackgroundColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.pending:
        return const Color(0xFFFFF6E6);
      case TransactionStatus.failed:
        return const Color(0xFFFFEEF0);
      case TransactionStatus.successful:
        return const Color(0xFFE4FAF1);
    }
  }
}

class _InfoRowData {
  const _InfoRowData({
    required this.label,
    required this.value,
    this.isMultiline = false,
  });

  final String label;
  final String value;
  final bool isMultiline;
}

class _TransactionInfoRow extends StatelessWidget {
  const _TransactionInfoRow({required this.data});

  final _InfoRowData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: data.isMultiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            data.label,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            data.value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black,
              height: data.isMultiline ? 1.4 : 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionButtonData {
  const _ActionButtonData({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.data});

  final _ActionButtonData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18.r),
      onTap: () {},
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: data.backgroundColor,
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: data.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(data.icon, color: data.textColor, size: 20.sp),
            vSpace(6),
            Text(
              data.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: data.textColor,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomCtaButton extends StatelessWidget {
  const _BottomCtaButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18.r),
      onTap: onTap,
      child: Container(
        height: 56.h,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foregroundColor, size: 20.sp),
            hSpace(8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankAvatar extends StatelessWidget {
  const _BankAvatar({this.bankLogoAsset, required this.initials});

  final String? bankLogoAsset;
  final String initials;

  @override
  Widget build(BuildContext context) {
    if (bankLogoAsset != null && bankLogoAsset!.isNotEmpty) {
      return Container(
        width: 52.w,
        height: 52.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey.shade100,
          image: DecorationImage(
            image: AssetImage(bankLogoAsset!),
            fit: BoxFit.contain,
          ),
        ),
      );
    }

    return Container(
      width: 52.w,
      height: 52.w,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFFCE7EC),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFD7263D),
        ),
      ),
    );
  }
}
