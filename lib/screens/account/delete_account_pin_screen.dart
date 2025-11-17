import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/pin_input_field.dart';

class DeleteAccountPinScreen extends StatefulWidget {
  const DeleteAccountPinScreen({super.key});

  @override
  State<DeleteAccountPinScreen> createState() =>
      _DeleteAccountPinScreenState();
}

class _DeleteAccountPinScreenState extends State<DeleteAccountPinScreen> {
  bool _obscurePin = true;
  bool _showError = false;

  void _handlePinCompleted(String pin) {
    // TODO: Verify PIN with backend
    // For now, simulate PIN verification
    if (pin == '2222') {
      // Correct PIN - proceed to second confirmation screen
      context.pushNamed('delete-account-final-confirmation');
    } else {
      // Incorrect PIN
      setState(() {
        _showError = true;
      });
    }
  }

  void _handlePinChanged(String pin) {
    if (_showError && pin.isEmpty) {
      setState(() {
        _showError = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
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
            'Delete your Account',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(32.w),
            decoration: const BoxDecoration(
              color: Colors.white,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7434FF).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    color: const Color(0xFF7434FF),
                    size: 50.sp,
                  ),
                ),
                vSpace(32),
                Text(
                  'Verify Your PIN',
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F1D40),
                  ),
                ),
                vSpace(12),
                Text(
                  'Enter your transaction PIN to confirm deleting of your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
                vSpace(40),
                PinInputField(
                  obscureText: _obscurePin,
                  onCompleted: _handlePinCompleted,
                  onChanged: _handlePinChanged,
                ),
                vSpace(24),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _obscurePin = !_obscurePin;
                    });
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _obscurePin
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18.sp,
                        color: Colors.grey.shade600,
                      ),
                      hSpace(8),
                      Text(
                        'Show PIN',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_showError) ...[
                  vSpace(24),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20.w,
                          height: 20.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD32F2F),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '!',
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        hSpace(12),
                        Expanded(
                          child: Text(
                            'Incorrect PIN entered, please try again',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: const Color(0xFFD32F2F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

