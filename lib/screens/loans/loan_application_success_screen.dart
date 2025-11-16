import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class LoanApplicationSuccessScreen extends StatelessWidget {
  const LoanApplicationSuccessScreen({
    super.key,
    required this.loanAmount,
    this.applicationId,
  });

  final double loanAmount;
  final String? applicationId;

  String get _applicationId => applicationId ?? _generateApplicationId();
  String get _formattedAmount {
    final formatter = NumberFormat('#,##0', 'en_NG');
    return '₦${formatter.format(loanAmount.round())}';
  }

  String _generateApplicationId() {
    final now = DateTime.now();
    final year = now.year;
    final random = (now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0');
    return 'LNA-$year-$random';
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: Colors.grey.shade50,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Loan Application',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
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
                  _buildHeading(),
                  vSpace(16),
                  _buildDescription(),
                  vSpace(24),
                  _buildApplicationDetails(),
                  vSpace(24),
                  _buildActionButtons(context),
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
      child: const Icon(
        Icons.check,
        color: Colors.white,
        size: 60,
      ),
    );
  }

  Widget _buildHeading() {
    return Text(
      'Application Submitted!',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 22.sp,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildDescription() {
    return Text(
      'Your loan application for $_formattedAmount has been submitted successfully. You\'ll receive a response within 24-48 hours.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13.sp,
        color: Colors.grey.shade800,
        height: 1.4,
      ),
    );
  }

  Widget _buildApplicationDetails() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Application ID', _applicationId),
          vSpace(20),
          Divider(height: 1, color: Colors.grey.shade300),
          vSpace(20),
          _buildDetailRow('Amount Requested', _formattedAmount),
          vSpace(20),
          Divider(height: 1, color: Colors.grey.shade300),
          vSpace(20),
          _buildDetailRow('Status', 'Under Review', isStatus: true),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: isStatus ? const Color(0xFFE67E22) : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              context.goNamed('loans');
            },
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
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        vSpace(12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              context.goNamed('home');
            },
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
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

