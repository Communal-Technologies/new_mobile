import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/screens/obligations/data/sample_obligations.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class ObligationConfirmPaymentScreen extends StatefulWidget {
  const ObligationConfirmPaymentScreen({
    super.key,
    required this.obligation,
    required this.amount,
    required this.method,
  });

  final Obligation obligation;
  final double amount;
  final String method;

  @override
  State<ObligationConfirmPaymentScreen> createState() =>
      _ObligationConfirmPaymentScreenState();
}

class _ObligationConfirmPaymentScreenState
    extends State<ObligationConfirmPaymentScreen> {
  late final List<TextEditingController> _pinControllers;
  late final List<FocusNode> _pinFocusNodes;
  bool _obscurePin = true;

  @override
  void initState() {
    super.initState();
    _pinControllers = List.generate(
      4,
      (_) => TextEditingController(),
      growable: false,
    );
    _pinFocusNodes = List.generate(4, (_) => FocusNode(), growable: false);
  }

  @override
  void dispose() {
    for (final controller in _pinControllers) {
      controller.dispose();
    }
    for (final node in _pinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Confirm Payment',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              color: const Color(0xFF7434FF),
              size: 44.sp,
            ),
            vSpace(16),
            Text(
              'Enter Your PIN',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            vSpace(6),
            Text(
              'Enter your 4-digit transaction PIN to authorize this payment',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
            ),
            vSpace(24),
            _buildAmountBanner(),
            vSpace(24),
            _buildPinInputs(),
            vSpace(12),
            TextButton.icon(
              onPressed: () => setState(() => _obscurePin = !_obscurePin),
              icon: Icon(
                _obscurePin ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey.shade700,
                size: 18.sp,
              ),
              label: Text(
                _obscurePin ? 'Show PIN' : 'Hide PIN',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            vSpace(24),
            _buildSecureInfo(),
            vSpace(32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7434FF),
                  minimumSize: Size(double.infinity, 52.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
                child: Text(
                  'Authorize Payment',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
      decoration: BoxDecoration(
        color: const Color(0xFFEFE7FF),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        children: [
          Text(
            "You're paying",
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
          ),
          vSpace(4),
          Text(
            '₦${widget.amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF7434FF),
            ),
          ),
          vSpace(4),
          Text(
            'to ${widget.obligation.category}',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade600),
          ),
          Text(
            widget.obligation.title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinInputs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        4,
        (index) => SizedBox(
          width: 60.w,
          child: TextField(
            controller: _pinControllers[index],
            focusNode: _pinFocusNodes[index],
            textAlign: TextAlign.center,
            obscureText: _obscurePin,
            maxLength: 1,
            keyboardType: TextInputType.number,
            style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w700),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(
                  color: Color(0xFF7434FF),
                  width: 2,
                ),
              ),
            ),
            onChanged: (value) => _handlePinInput(index, value),
          ),
        ),
      ),
    );
  }

  Widget _buildSecureInfo() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F1FF),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: const Color(0xFF4A90E2), size: 20.sp),
          hSpace(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure Payment',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F1D40),
                  ),
                ),
                vSpace(4),
                Text(
                  'Your transaction is encrypted and secure. Never share your PIN with anyone.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handlePinInput(int index, String value) {
    if (value.isNotEmpty) {
      if (index < _pinFocusNodes.length - 1) {
        _pinFocusNodes[index + 1].requestFocus();
      } else {
        _pinFocusNodes[index].unfocus();
      }
    } else if (index > 0) {
      _pinFocusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  void _onConfirm() {
    final pin = _pinControllers.map((c) => c.text).join();
    if (pin.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your 4-digit PIN to continue.')),
      );
      return;
    }

    final reference = 'REF-${DateTime.now().millisecondsSinceEpoch}';

    context.pushNamed(
      'obligation-payment-success',
      extra: {
        'obligation': widget.obligation,
        'amount': widget.amount,
        'method': widget.method,
        'reference': reference,
        'date': DateTime.now(),
      },
    );
  }
}
