import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:communal_mobile/core/widgets/app_toast.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/repositories/transactions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/transactions/models/transaction_details_data.dart';

/// Lets a member report a problem with a specific transaction. The report goes
/// to the COMMUNAL platform admin (not the cooperative) via transactions-svc.
class ReportTransactionIssueScreen extends StatefulWidget {
  const ReportTransactionIssueScreen({super.key, required this.details});

  final TransactionDetailsData details;

  @override
  State<ReportTransactionIssueScreen> createState() =>
      _ReportTransactionIssueScreenState();
}

class _ReportTransactionIssueScreenState
    extends State<ReportTransactionIssueScreen> {
  static const _categories = <String>[
    'Wrong amount',
    "I didn't receive it",
    'Duplicate charge',
    'Unauthorized transaction',
    'Other',
  ];

  late final TransactionsRepository _repo =
      TransactionsRepository(getIt<DioClient>());
  final TextEditingController _descCtrl = TextEditingController();
  String? _category;
  bool _submitting = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final category = _category;
    final desc = _descCtrl.text.trim();
    if (category == null) {
      AppToast.error('Please choose what went wrong.');
      return;
    }
    if (desc.isEmpty) {
      AppToast.error('Please describe the issue.');
      return;
    }
    setState(() => _submitting = true);
    try {
      final d = widget.details;
      final msg = await _repo.submitTransactionIssue(
        category: category,
        description: desc,
        transactionReference: d.reference,
        transactionType: d.transactionType,
        amountMinor: (d.amount * 100).round(),
        currency: d.currencyCode ?? 'NGN',
      );
      if (!mounted) return;
      AppToast.success(msg);
      context.pop();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return AnnotatedRegion(
      value: systemOverlayForTheme(theme),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.cardColor,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: onSurface, size: 22.sp),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Report an issue',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 24.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This report goes to the Communal support team. Tell us what '
                  'went wrong with this transaction and we’ll look into it.',
                  style: TextStyle(
                    fontSize: 15.sp,
                    height: 1.4,
                    color: onSurface.withValues(alpha: 0.7),
                  ),
                ),
                vSpace(8),
                _transactionSummary(theme, onSurface),
                vSpace(20),
                Text(
                  'What went wrong?',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                vSpace(12),
                Wrap(
                  spacing: 10.w,
                  runSpacing: 10.h,
                  children: [
                    for (final c in _categories)
                      _categoryChip(c, theme, onSurface),
                  ],
                ),
                vSpace(20),
                Text(
                  'Describe the issue',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                vSpace(12),
                TextField(
                  controller: _descCtrl,
                  maxLines: 5,
                  maxLength: 1000,
                  style: TextStyle(fontSize: 15.sp, color: onSurface),
                  decoration: InputDecoration(
                    hintText: 'Tell us what happened…',
                    filled: true,
                    fillColor: theme.cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14.r),
                      borderSide:
                          BorderSide(color: theme.primaryColor, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
            child: SizedBox(
              height: 54.h,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: _submitting
                    ? SizedBox(
                        width: 22.w,
                        height: 22.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Submit report',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _transactionSummary(ThemeData theme, Color onSurface) {
    final d = widget.details;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            d.transactionType,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: onSurface,
            ),
          ),
          vSpace(4),
          Text(
            '${d.amountLabel} · ${d.reference}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.sp,
              color: onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, ThemeData theme, Color onSurface) {
    final selected = _category == label;
    return GestureDetector(
      onTap: () => setState(() => _category = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: selected
              ? theme.primaryColor.withValues(alpha: 0.12)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(
            color: selected ? theme.primaryColor : theme.dividerColor,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? theme.primaryColor : onSurface.withValues(alpha: 0.8),
          ),
        ),
      ),
    );
  }
}
