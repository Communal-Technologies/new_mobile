import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';

enum ReceiptAction { preview, download, share }

class TransactionReceiptScreen extends StatefulWidget {
  const TransactionReceiptScreen({
    super.key,
    required this.details,
    this.initialAction,
  });

  final TransactionDetailsData details;
  final ReceiptAction? initialAction;

  @override
  State<TransactionReceiptScreen> createState() =>
      _TransactionReceiptScreenState();
}

class _TransactionReceiptScreenState extends State<TransactionReceiptScreen> {
  final GlobalKey _receiptKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        switch (widget.initialAction!) {
          case ReceiptAction.download:
            _downloadReceipt();
            break;
          case ReceiptAction.share:
            _shareReceipt();
            break;
          case ReceiptAction.preview:
            break;
        }
      });
    }
  }

  Future<void> _downloadReceipt() async {
    final bytes = await _captureReceiptImage();
    if (!mounted) return;

    if (bytes == null) {
      _showSnack('Could not prepare receipt for download.');
      return;
    }

    if (!await _ensureGalleryPermission()) {
      return;
    }

    try {
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name:
            'communal_receipt_${_receiptIdentifier}_${DateTime.now().millisecondsSinceEpoch}',
        isReturnImagePathOfIOS: true,
      );

      final success =
          (result['isSuccess'] ?? result['success'] ?? false) == true;
      if (!success) throw Exception(result);

      final savedPath =
          result['filePath'] ?? result['path'] ?? result['fileUri'];
      _showSnack(
        savedPath != null
            ? 'Receipt saved to gallery\n$savedPath'
            : 'Receipt saved to gallery',
      );
    } catch (e) {
      debugPrint('Receipt save failed: $e');
      _showSnack('Unable to save receipt.');
    }
  }

  Future<void> _shareReceipt() async {
    final bytes = await _captureReceiptImage();
    if (!mounted) return;

    if (bytes == null) {
      _showSnack('Unable to capture receipt.');
      return;
    }

    try {
      await Share.shareXFiles(
        [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'communal_receipt.png',
          ),
        ],
        text:
            'Transaction receipt • ${widget.details.transactionType} • ${widget.details.amountLabel}',
      );
    } catch (e) {
      debugPrint('Receipt share failed: $e');
      _showSnack('Unable to share receipt.');
    }
  }

  Future<Uint8List?> _captureReceiptImage() async {
    try {
      final boundary =
          _receiptKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        return null;
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Receipt capture failed: $e');
      return null;
    }
  }

  String get _receiptIdentifier {
    final raw = widget.details.reference;
    final sanitized = raw.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_');
    return sanitized.isEmpty ? 'transaction' : sanitized;
  }

  Future<bool> _ensureGalleryPermission() async {
    if (kIsWeb) return true;

    Future<bool> requestPermission(
      Permission permission, {
      bool treatLimitedAsGranted = false,
    }) async {
      final status = await permission.request();
      if (status.isGranted ||
          (treatLimitedAsGranted && status.isLimited == true)) {
        return true;
      }
      if (status.isPermanentlyDenied) {
        _showSnack(
          'Permission permanently denied. Enable it from Settings to save receipts.',
        );
        await openAppSettings();
      }
      return false;
    }

    Future<bool> hasPermission(
      Permission permission, {
      bool treatLimitedAsGranted = false,
    }) async {
      final status = await permission.status;
      return status.isGranted ||
          (treatLimitedAsGranted && status.isLimited == true);
    }

    if (Platform.isIOS) {
      if (await hasPermission(
            Permission.photosAddOnly,
            treatLimitedAsGranted: true,
          ) ||
          await hasPermission(Permission.photos, treatLimitedAsGranted: true)) {
        return true;
      }
      if (await requestPermission(
        Permission.photosAddOnly,
        treatLimitedAsGranted: true,
      )) {
        return true;
      }
      if (await requestPermission(
        Permission.photos,
        treatLimitedAsGranted: true,
      )) {
        return true;
      }
      return false;
    }

    if (Platform.isAndroid) {
      if (await hasPermission(Permission.photos) ||
          await hasPermission(Permission.storage) ||
          await hasPermission(Permission.manageExternalStorage)) {
        return true;
      }
      if (await requestPermission(Permission.photos)) return true;
      if (await requestPermission(Permission.storage)) return true;
      if (await requestPermission(Permission.manageExternalStorage)) {
        return true;
      }
      return false;
    }

    if (await hasPermission(Permission.storage)) {
      return true;
    }

    return requestPermission(Permission.storage);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

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
        backgroundColor: const Color(0xFFF7F8FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFF7F8FB),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              size: 18.sp,
              color: Colors.black,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Transaction Receipt',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            child: Column(
              children: [
                RepaintBoundary(
                  key: _receiptKey,
                  child: _ReceiptCard(details: widget.details),
                ),
                vSpace(24),
                Row(
                  children: [
                    Expanded(
                      child: _ReceiptActionButton(
                        label: 'Download',
                        icon: Iconsax.import,
                        background: const Color(0xFFF0E6FF),
                        foreground: theme.primaryColor,
                        onTap: _downloadReceipt,
                      ),
                    ),
                    hSpace(12),
                    Expanded(
                      child: _ReceiptActionButton(
                        label: 'Share',
                        icon: Iconsax.export_1,
                        background: theme.primaryColor,
                        foreground: Colors.white,
                        onTap: _shareReceipt,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.details});

  final TransactionDetailsData details;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 28.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Image.asset(
                Images.coloredLogo,
                height: 32.h,
                fit: BoxFit.contain,
              ),
              const Spacer(),
              Text(
                'Transaction Receipt',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          vSpace(24),
          Text(
            details.amountLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 36.sp,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: -0.5,
            ),
          ),
          vSpace(12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              text: '${details.counterpartLabel} ',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
              children: [
                TextSpan(
                  text: details.counterpartyName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          vSpace(4),
          Text(
            details.formattedDate,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
              letterSpacing: 0.6,
            ),
          ),
          vSpace(16),
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: _statusBackgroundColor,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_statusIcon, size: 16.sp, color: _statusColor),
                  hSpace(6),
                  Text(
                    _statusLabel,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: _statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          vSpace(24),
          Divider(color: Colors.grey.shade200, thickness: 1),
          vSpace(20),
          _ReceiptInfoRow(label: 'Fees', value: details.feesLabel),
          vSpace(16),
          _ReceiptInfoRow(
            label: details.isIncoming ? 'Sender Details' : 'Recipient Details',
            value:
                '${details.counterpartyName}\n${details.counterpartyBankLine}',
            isMultiline: true,
          ),
          vSpace(16),
          _ReceiptInfoRow(
            label: 'Transaction Type',
            value: details.transactionType,
          ),
          vSpace(16),
          _ReceiptInfoRow(label: 'Date and Time', value: details.formattedDate),
          vSpace(16),
          _ReceiptInfoRow(label: 'Session ID', value: details.sessionId),
          vSpace(16),
          _ReceiptInfoRow(label: 'Description', value: details.description),
          vSpace(16),
          _ReceiptInfoRow(
            label: 'Transaction Reference',
            value: details.reference,
          ),
          vSpace(16),
          _ReceiptInfoRow(
            label: 'Payment Method',
            value: details.paymentMethod,
          ),
          vSpace(24),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: const Color(0xFFE6FBFF),
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Iconsax.info_circle,
                  size: 18.sp,
                  color: const Color(0xFF4CB0C9),
                ),
                hSpace(10),
                Expanded(
                  child: Text(
                    details.note ??
                        'This is a computer generated receipt and does not require a signature.',
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
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

extension _ReceiptStatusStyling on _ReceiptCard {
  Color get _statusColor {
    switch (details.status) {
      case TransactionStatus.pending:
        return const Color(0xFFE6A502);
      case TransactionStatus.failed:
        return const Color(0xFFD7263D);
      case TransactionStatus.successful:
        return const Color(0xFF1AAE70);
    }
  }

  Color get _statusBackgroundColor {
    switch (details.status) {
      case TransactionStatus.pending:
        return const Color(0xFFFFF6E6);
      case TransactionStatus.failed:
        return const Color(0xFFFFEEF0);
      case TransactionStatus.successful:
        return const Color(0xFFE4FAF1);
    }
  }

  IconData get _statusIcon {
    switch (details.status) {
      case TransactionStatus.pending:
        return Iconsax.clock;
      case TransactionStatus.failed:
        return Iconsax.close_circle;
      case TransactionStatus.successful:
        return Iconsax.tick_circle;
    }
  }

  String get _statusLabel {
    switch (details.status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.failed:
        return 'Failed';
      case TransactionStatus.successful:
        return 'Successful';
    }
  }
}

class _ReceiptInfoRow extends StatelessWidget {
  const _ReceiptInfoRow({
    required this.label,
    required this.value,
    this.isMultiline = false,
  });

  final String label;
  final String value;
  final bool isMultiline;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: isMultiline
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
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
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              height: isMultiline ? 1.4 : 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReceiptActionButton extends StatelessWidget {
  const _ReceiptActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        height: 56.h,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: foreground, size: 20.sp),
            hSpace(8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
