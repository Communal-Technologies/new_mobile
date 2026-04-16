import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/loans/data/sample_guarantors.dart';

class LoanApplicationStep3Screen extends StatefulWidget {
  const LoanApplicationStep3Screen({
    super.key,
    this.loanAmount,
    this.loanDuration,
    this.loanPurpose,
    this.firstGuarantor,
    this.secondGuarantor,
  });

  final double? loanAmount;
  final int? loanDuration;
  final String? loanPurpose;
  final Guarantor? firstGuarantor;
  final Guarantor? secondGuarantor;

  @override
  State<LoanApplicationStep3Screen> createState() => _LoanApplicationStep3ScreenState();
}

class _LoanApplicationStep3ScreenState extends State<LoanApplicationStep3Screen> {
  bool _agreedToTerms = false;
  final double _interestRate = 12.0;

  double get _loanAmount => widget.loanAmount ?? 500000;
  int get _loanDuration => widget.loanDuration ?? 12;
  String get _loanPurpose => widget.loanPurpose ?? 'Education';

  double get _monthlyPayment {
    if (_loanDuration == 0) return 0;
    final monthlyRate = _interestRate / 100 / 12;
    if (monthlyRate == 0) return _loanAmount / _loanDuration;
    final numerator = _loanAmount * monthlyRate * _pow(1 + monthlyRate, _loanDuration);
    final denominator = _pow(1 + monthlyRate, _loanDuration) - 1;
    return numerator / denominator;
  }

  double _pow(double base, int exponent) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_NG');
    return '₦${formatter.format(amount)}';
  }

  String _formatCurrencyNoDecimals(double amount) {
    final formatter = NumberFormat('#,##0', 'en_NG');
    return formatter.format(amount.round());
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
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
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
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 16.w),
              child: Center(
                child: Text(
                  'Step 3 of 3',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF7434FF),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressIndicator(),
                    vSpace(24),
                    _buildLoanSummaryCard(),
                    vSpace(24),
                    _buildGuarantorsCard(),
                    vSpace(24),
                    _buildTermsAndConditionsCard(),
                    vSpace(24),
                    _buildImportantNoticeCard(),
                    vSpace(24),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: _buildNavigationButtons(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Review & Submit',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF7434FF),
            ),
          ),
        ),
        vSpace(8),
        Stack(
          children: [
            Container(
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            FractionallySizedBox(
              widthFactor: 1.0,
              child: Container(
                height: 4.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF7434FF),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoanSummaryCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Loan Summary',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(20),
          _buildSummaryRow('Loan Amount', _formatCurrencyNoDecimals(_loanAmount)),
          vSpace(16),
          _buildSummaryRow('Duration', '$_loanDuration months'),
          vSpace(16),
          _buildSummaryRow('Interest Rate', '${_interestRate.toStringAsFixed(0)}% per annum'),
          vSpace(16),
          _buildSummaryRow('Monthly Payment', _formatCurrency(_monthlyPayment)),
          vSpace(16),
          _buildSummaryRow('Purpose', _loanPurpose),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF0F1D40),
          ),
        ),
      ],
    );
  }

  Widget _buildGuarantorsCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Guarantors',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(16),
          if (widget.firstGuarantor != null)
            _buildGuarantorItem(widget.firstGuarantor!),
          if (widget.firstGuarantor != null && widget.secondGuarantor != null) vSpace(12),
          if (widget.secondGuarantor != null)
            _buildGuarantorItem(widget.secondGuarantor!),
        ],
      ),
    );
  }

  Widget _buildGuarantorItem(Guarantor guarantor) {
    return Row(
      children: [
        Icon(
          Icons.check_circle,
          color: const Color(0xFF4CAF50),
          size: 24.sp,
        ),
        hSpace(12),
        Expanded(
          child: Text(
            guarantor.name,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F1D40),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsAndConditionsCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _agreedToTerms = !_agreedToTerms;
              });
            },
            child: Container(
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: _agreedToTerms ? const Color(0xFF7434FF) : Colors.transparent,
                border: Border.all(
                  color: _agreedToTerms ? const Color(0xFF7434FF) : Colors.grey.shade400,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: _agreedToTerms
                  ? Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16.sp,
                    )
                  : null,
            ),
          ),
          hSpace(12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'terms and conditions',
                    style: TextStyle(
                      color: const Color(0xFF7434FF),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' of the loan agreement and understand that this is a legally binding commitment to repay the loan.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportantNoticeCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Important:',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(8),
          Text(
            'Your application will be reviewed within 24-48 hours. You will be notified of the decision via SMS and email.',
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        SizedBox(
          width: 100.w,
          child: OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey.shade300),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(vertical: 16.h),
            ),
            child: Text(
              'Back',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F1D40),
              ),
            ),
          ),
        ),
        hSpace(12),
        Expanded(
          child: ElevatedButton(
            onPressed: _agreedToTerms
                ? () {
                    context.pushReplacementNamed('loan-application-success', extra: {
                      'amount': _loanAmount,
                    });
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7434FF),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              padding: EdgeInsets.symmetric(vertical: 16.h),
            ),
            child: Text(
              'Submit Application',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

