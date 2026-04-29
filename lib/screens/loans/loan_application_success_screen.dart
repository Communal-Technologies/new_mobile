import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/utils/money.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class LoanApplicationSuccessScreen extends StatelessWidget {
  const LoanApplicationSuccessScreen({
    super.key,
    required this.amountMinor,
    required this.currency,
    this.referenceId,
    this.message,
  });

  /// Loan principal in integer minor units of [currency] (kobo for NGN).
  final int amountMinor;
  final String currency;

  /// Backend `reference_id` for the new application. Null when the
  /// store endpoint didn't include it in the response — in that case
  /// the screen surfaces "pending review" without an id.
  final String? referenceId;

  /// Optional success message from the server (e.g. "your guarantors
  /// have been notified for approval").
  final String? message;

  @override
  Widget build(BuildContext context) {
    final formattedAmount = Money(amountMinor, currency).format();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'Loan Application',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildSuccessIndicator(),
                  vSpace(24),
                  Text(
                    'Application Submitted!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  vSpace(16),
                  Text(
                    message ??
                        'Your loan application for $formattedAmount has been submitted. Your guarantors will review it and your cooperative will reach out with a decision.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                  vSpace(24),
                  _buildDetails(context, formattedAmount),
                  vSpace(24),
                  _buildActions(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIndicator() {
    return Container(
      width: 100.w,
      height: 100.w,
      decoration: const BoxDecoration(
        color: Color(0xFF4CAF50),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.check, color: Colors.white, size: 60),
    );
  }

  Widget _buildDetails(BuildContext context, String formattedAmount) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (referenceId != null && referenceId!.isNotEmpty) ...[
            _detailRow(context,'Reference', referenceId!),
            vSpace(20),
            Divider(height: 1, color: Colors.grey.shade300),
            vSpace(20),
          ],
          _detailRow(context,'Amount Requested', formattedAmount),
          vSpace(20),
          Divider(height: 1, color: Colors.grey.shade300),
          vSpace(20),
          _detailRow(context,'Status', 'Under Review', isStatus: true),
        ],
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value,
      {bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15.sp,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: isStatus ? const Color(0xFFE67E22) : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.goNamed('loans'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7434FF),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'Go to Loans',
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        vSpace(12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.goNamed('home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.black87,
              elevation: 0,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'Back to Home',
              style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
