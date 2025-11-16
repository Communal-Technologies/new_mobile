import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class LoanApplicationScreen extends StatefulWidget {
  const LoanApplicationScreen({
    super.key,
    this.initialAmount,
    this.initialDuration,
    this.currencySymbol = '₦',
  });

  final double? initialAmount;
  final int? initialDuration;
  final String currencySymbol;

  @override
  State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  double _loanAmount = 500000;
  int _loanDuration = 12;
  final double _interestRate = 12.0;
  final double _minAmount = 50000;
  final double _maxAmount = 2000000;
  final TextEditingController _loanUsageController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialAmount != null) {
      _loanAmount = widget.initialAmount!;
    }
    if (widget.initialDuration != null) {
      _loanDuration = widget.initialDuration!;
    }
    _loanUsageController.text = 'I want to upgrade my business';
    _amountController.text = _formatCurrencyNoDecimals(_loanAmount);
    _amountController.addListener(_onAmountChanged);
  }

  void _onAmountChanged() {
    final text = _amountController.text.replaceAll(RegExp(r'[^\d]'), '');
    if (text.isNotEmpty) {
      final value = double.tryParse(text) ?? 0;
      if (value != _loanAmount) {
        setState(() {
          _loanAmount = value.clamp(_minAmount, _maxAmount);
        });
        // Update controller if value was clamped
        if (value != _loanAmount) {
          _amountController.value = TextEditingValue(
            text: _formatCurrencyNoDecimals(_loanAmount),
            selection: TextSelection.collapsed(
              offset: _formatCurrencyNoDecimals(_loanAmount).length,
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _loanUsageController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  double get _monthlyPayment {
    if (_loanDuration == 0) return 0;
    final monthlyRate = _interestRate / 100 / 12;
    if (monthlyRate == 0) return _loanAmount / _loanDuration;
    final numerator = _loanAmount * monthlyRate * math.pow(1 + monthlyRate, _loanDuration);
    final denominator = math.pow(1 + monthlyRate, _loanDuration) - 1;
    return numerator / denominator;
  }

  double get _totalRepayment => _monthlyPayment * _loanDuration;
  double get _totalInterest => _totalRepayment - _loanAmount;
  int get _numberOfInstallments => _loanDuration;

  String _formatCurrency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_NG');
    return '${widget.currencySymbol}${formatter.format(amount)}';
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
                    vSpace(32),
                    _buildLoanAmountSection(),
                    vSpace(24),
                    _buildRepaymentSummarySection(),
                    vSpace(32),
                    _buildLoanUsageSection(),
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
                child: _buildContinueButton(),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Loan Details',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7434FF),
              ),
            ),
            Text(
              'Step 1 of 3',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF7434FF),
              ),
            ),
          ],
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
              widthFactor: 1 / 3,
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

  Widget _buildLoanAmountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'How much do you need?',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(20),
            Row(
          children: [
            Text(
              '${widget.currencySymbol}${_formatCurrencyNoDecimals(_minAmount)}',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade600,
              ),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF7434FF),
                  inactiveTrackColor: Colors.grey.shade300,
                  thumbColor: const Color(0xFF7434FF),
                  thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12.r),
                  overlayShape: RoundSliderOverlayShape(overlayRadius: 24.r),
                  trackHeight: 4.h,
                ),
                child: Slider(
                  value: _loanAmount,
                  min: _minAmount,
                  max: _maxAmount,
                  divisions: 39,
                  onChanged: (value) {
                    setState(() {
                      _loanAmount = value;
                      // Update text field when slider changes
                      _amountController.value = TextEditingValue(
                        text: _formatCurrencyNoDecimals(_loanAmount),
                        selection: TextSelection.collapsed(
                          offset: _formatCurrencyNoDecimals(_loanAmount).length,
                        ),
                      );
                    });
                  },
                ),
              ),
            ),
            Text(
              '${widget.currencySymbol}${_formatCurrencyNoDecimals(_maxAmount)}',
              style: TextStyle(
                fontSize: 13.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        vSpace(16),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF7434FF),
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d,]')),
          ],
          decoration: InputDecoration(
            prefixText: widget.currencySymbol,
            prefixStyle: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7434FF),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF7434FF), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          ),
          onChanged: (value) {
            // Format the input as user types
            final numericValue = value.replaceAll(RegExp(r'[^\d]'), '');
            if (numericValue.isNotEmpty) {
              final numValue = int.tryParse(numericValue) ?? 0;
              final formatted = _formatCurrencyNoDecimals(numValue.toDouble());
              if (formatted != value) {
                _amountController.value = TextEditingValue(
                  text: formatted,
                  selection: TextSelection.collapsed(
                    offset: formatted.length,
                  ),
                );
              }
            }
          },
        ),
        vSpace(8),
        Text(
          'Minimum: ${widget.currencySymbol}${_formatCurrencyNoDecimals(_minAmount)} | Maximum: ${widget.currencySymbol}${_formatCurrencyNoDecimals(_maxAmount)}',
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildRepaymentSummarySection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Repayment Summary',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatCurrency(_monthlyPayment),
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7434FF),
                      ),
                    ),
                    vSpace(4),
                    Text(
                      'monthly in $_numberOfInstallments installments',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatCurrency(_totalRepayment),
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7434FF),
                      ),
                    ),
                    vSpace(4),
                    Text(
                      'Total Repayment',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          vSpace(16),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Interest',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  _formatCurrencyNoDecimals(_totalInterest),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F1D40),
                  ),
                ),
              ],
            ),
          ),
          vSpace(12),
          Text(
            'At ${_interestRate.toStringAsFixed(0)}% annual interest rate',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFE67E22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanUsageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What will you use this loan for?',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(16),
        TextField(
          controller: _loanUsageController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'I want to upgrade my business',
            hintStyle: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade400,
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.r),
              borderSide: const BorderSide(color: Color(0xFF7434FF), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          ),
          style: TextStyle(
            fontSize: 14.sp,
            color: const Color(0xFF0F1D40),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          context.pushNamed('loan-application-step2', extra: {
            'amount': _loanAmount,
            'duration': _loanDuration,
            'purpose': _loanUsageController.text,
          });
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
          'Continue',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

