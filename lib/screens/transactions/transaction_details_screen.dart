import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';

String _counterpartyInitials(String name, String bank) {
  final n = name.trim();
  if (n.isEmpty) {
    final b = bank.trim();
    if (b.length >= 2) return b.substring(0, 2).toUpperCase();
    return 'BK';
  }
  final parts = n.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.length >= 2) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return n.length >= 2 ? n.substring(0, 2).toUpperCase() : n.toUpperCase();
}

class TransactionDetailsScreen extends StatelessWidget {
  const TransactionDetailsScreen({super.key, required this.details});

  final TransactionDetailsData details;
  static const String _receiptDownloadAction = 'download';
  static const String _receiptShareAction = 'share';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F2FA),
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: Theme.of(context).colorScheme.onSurface, size: 22.sp),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Transaction details',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 28.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(context, theme),
                vSpace(14),
                _buildDetailsCard(theme),
                if (details.note != null) ...[
                  vSpace(16),
                  _buildNoteCard(context, theme),
                ],
                vSpace(20),
                _buildActionsSection(context, theme),
                vSpace(32),
              ],
            ),
          ),
        ),
        bottomNavigationBar: details.status == TransactionStatus.successful
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: _BottomCtaButton(
                          label: 'Download',
                          icon: Iconsax.import,
                          backgroundColor: const Color(0xFFF0E6FF),
                          foregroundColor: theme.primaryColor,
                          onTap: () =>
                              _openReceipt(context, _receiptDownloadAction),
                        ),
                      ),
                      hSpace(12),
                      Expanded(
                        child: _BottomCtaButton(
                          label: 'Share',
                          icon: Iconsax.export_1,
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          onTap: () =>
                              _openReceipt(context, _receiptShareAction),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  void _openReceipt(BuildContext context, String action) {
    if (details.status != TransactionStatus.successful) return;
    context.pushNamed(
      'transaction-receipt',
      extra: {'details': details, 'action': action},
    );
  }

  Color _amountDisplayColor() {
    if (details.status == TransactionStatus.failed) {
      return Colors.grey.shade800;
    }
    if (details.isIncoming) return const Color(0xFF1AAE70);
    return const Color(0xFF0F1D40);
  }

  Widget _buildSummaryCard(BuildContext context, ThemeData theme) {
    final statusColor = _statusColor(details.status, theme);
    final statusBackground = _statusBackgroundColor(details.status);
    final initials = _counterpartyInitials(
      details.counterpartyName,
      details.counterpartyBank,
    );
    final failure = details.failureReason?.trim();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 22.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BankAvatar(
                bankLogoAsset: details.bankLogoAsset,
                initials: initials,
              ),
              hSpace(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details.counterpartLabel,
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    vSpace(6),
                    Text(
                      details.counterpartyName,
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          vSpace(22),
          Text(
            details.amountLabel,
            style: TextStyle(
              fontSize: 36.sp,
              fontWeight: FontWeight.w800,
              color: _amountDisplayColor(),
              letterSpacing: -0.8,
            ),
          ),
          vSpace(14),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: statusBackground,
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _statusIcon(details.status),
                  size: 18.sp,
                  color: statusColor,
                ),
                hSpace(8),
                Text(
                  _statusLabel(details.status),
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
          if (details.status == TransactionStatus.failed &&
              failure != null &&
              failure.isNotEmpty) ...[
            vSpace(14),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: const Color(0xFFFFD4DB)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Iconsax.info_circle, size: 20.sp, color: Colors.red.shade700),
                  hSpace(10),
                  Expanded(
                    child: Text(
                      failure,
                      style: TextStyle(
                        fontSize: 15.sp,
                        height: 1.35,
                        color: Colors.grey.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < infoRows.length; i++) ...[
            _TransactionInfoRow(data: infoRows[i]),
            if (i != infoRows.length - 1)
              Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFBF5),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFC8E6D4)),
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
                fontSize: 15.sp,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context, ThemeData theme) {
    final actions = [
      _ActionTileData(
        label: 'Report issue',
        subtitle: 'Get help with this transaction',
        icon: Iconsax.warning_2,
        iconColor: const Color(0xFFD7263D),
        tileColor: const Color(0xFFFFF5F6),
        onTap: () => context.pushNamed('help-support'),
      ),
      _ActionTileData(
        label: 'View history',
        subtitle: 'Open full transaction list',
        icon: Iconsax.document_text5,
        iconColor: theme.primaryColor,
        tileColor: const Color(0xFFF6F2FF),
        onTap: () => context.goNamed('transactions'),
      ),
      _ActionTileData(
        label: 'Transfer again',
        subtitle: 'Send money from your wallet',
        icon: Iconsax.send_1,
        iconColor: Theme.of(context).colorScheme.onSurface,
        tileColor: Colors.white,
        onTap: () {
          context.pop();
          context.pushNamed('transfer');
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More actions',
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(10),
        Text(
          'Tap an option below',
          style: TextStyle(
            fontSize: 15.sp,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
        vSpace(14),
        Column(
          children: [
            for (int i = 0; i < actions.length; i++) ...[
              if (i != 0) vSpace(10),
              _ActionTile(data: actions[i], theme: theme),
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
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        crossAxisAlignment: data.isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              data.label,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.25,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              data.value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
                height: data.isMultiline ? 1.45 : 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTileData {
  const _ActionTileData({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.tileColor,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color tileColor;
  final VoidCallback onTap;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.data, required this.theme});

  final _ActionTileData data;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: data.tileColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Row(
            children: [
              Container(
                width: 46.w,
                height: 46.w,
                decoration: BoxDecoration(
                  color: data.iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                alignment: Alignment.center,
                child: Icon(data.icon, color: data.iconColor, size: 22.sp),
              ),
              hSpace(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.label,
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    vSpace(4),
                    Text(
                      data.subtitle,
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey.shade400,
                size: 26.sp,
              ),
            ],
          ),
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
        height: 54.h,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foregroundColor, size: 22.sp),
            hSpace(8),
            Text(
              label,
              style: TextStyle(
                fontSize: 17.sp,
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
          fontSize: 17.sp,
          fontWeight: FontWeight.w800,
          color: const Color(0xFFD7263D),
        ),
      ),
    );
  }
}
