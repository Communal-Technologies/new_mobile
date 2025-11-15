import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/obligations/data/sample_obligations.dart';

class ObligationPaymentScreen extends StatefulWidget {
  const ObligationPaymentScreen({super.key, required this.obligation});

  final Obligation obligation;

  @override
  State<ObligationPaymentScreen> createState() =>
      _ObligationPaymentScreenState();
}

class _ObligationPaymentScreenState extends State<ObligationPaymentScreen> {
  late final TextEditingController _amountController;
  final TextEditingController _noteController = TextEditingController();
  int _selectedMethodIndex = 0;

  final List<_PaymentMethodOption> _methods = [
    _PaymentMethodOption(
      title: 'Wallet',
      subtitle: 'Balance: ₦450,000',
      icon: Iconsax.wallet_check,
      highlightColor: const Color(0xFF7434FF),
    ),
    _PaymentMethodOption(
      title: 'Debit Card',
      subtitle: 'Pay with your card',
      icon: Iconsax.card,
      highlightColor: const Color(0xFFFFB65C),
    ),
    _PaymentMethodOption(
      title: 'Bank Transfer',
      subtitle: 'Pay from your bank',
      icon: Iconsax.building,
      highlightColor: const Color(0xFF5B8DFF),
    ),
  ];

  static const int _noteLimit = 100;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.obligation.perInstallment.toStringAsFixed(0),
    );
    _noteController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final outstanding = widget.obligation.balance.toStringAsFixed(0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F4F6),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'Make Payment',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewCard(outstanding),
              vSpace(24),
              _buildAmountInput(),
              vSpace(4),
              Text(
                'Suggested: ₦${widget.obligation.perInstallment.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
              ),
              vSpace(24),
              Text(
                'Payment Method',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              vSpace(12),
              Column(
                children: List.generate(
                  _methods.length,
                  (index) => Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _methods.length - 1 ? 0 : 12.h,
                    ),
                    child: _buildPaymentMethodTile(index),
                  ),
                ),
              ),
              vSpace(24),
              Text(
                'Narration (Optional)',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              vSpace(10),
              _buildNarrationField(),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
            child: ElevatedButton(
              onPressed: _onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7434FF),
                minimumSize: Size(double.infinity, 52.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
              ),
              child: Text(
                'Continue',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(String outstanding) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Paying for',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade500),
          ),
          vSpace(6),
          Text(
            widget.obligation.title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          Text(
            'Total Lenders Forum',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
          ),
          vSpace(16),
          Divider(color: Colors.grey.shade200),
          vSpace(12),
          Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  label: 'Installment Amount',
                  value:
                      '₦${widget.obligation.perInstallment.toStringAsFixed(0)}',
                ),
              ),
              Expanded(
                child: _MetricBlock(
                  label: 'Outstanding Balance',
                  value: '₦$outstanding',
                  alignRight: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Amount to Pay',
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        vSpace(10),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            prefixText: '₦ ',
            hintText: '50000',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16.r),
              borderSide: const BorderSide(color: Color(0xFF7434FF), width: 2),
            ),
          ),
          style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodTile(int index) {
    final method = _methods[index];
    final isSelected = _selectedMethodIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedMethodIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isSelected ? const Color(0xFF7434FF) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: method.highlightColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                method.icon,
                color: method.highlightColor,
                size: 22.sp,
              ),
            ),
            hSpace(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  vSpace(4),
                  Text(
                    method.subtitle,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? const Color(0xFF7434FF)
                  : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNarrationField() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _noteController,
            maxLines: 3,
            maxLength: _noteLimit,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Add a note for this payment...',
              counterText: '',
            ),
            style: TextStyle(fontSize: 14.sp),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_noteController.text.length}/$_noteLimit',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  void _onContinue() {
    final amount =
        double.tryParse(_amountController.text) ??
        widget.obligation.perInstallment;
    final method = _methods[_selectedMethodIndex].title;

    context.pushNamed(
      'obligation-confirm-payment',
      extra: {
        'obligation': widget.obligation,
        'amount': amount,
        'method': method,
      },
    );
  }
}

class _PaymentMethodOption {
  const _PaymentMethodOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.highlightColor,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color highlightColor;
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
    this.alignRight = false,
  });

  final String label;
  final String value;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final alignment = alignRight
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;

    return Column(
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
        ),
        vSpace(4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
