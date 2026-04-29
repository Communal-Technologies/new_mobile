import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/account_actions_repository.dart';
import 'package:communal_mobile/injection.dart';
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
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _handlePinCompleted(String pin) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _showError = false;
      _errorMessage = null;
    });
    try {
      await getIt<AccountActionsRepository>().verifySecurityPin(pin);
      if (!mounted) return;
      // ignore: unawaited_futures
      context.pushNamed('delete-account-final-confirmation');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _showError = true;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _handlePinChanged(String pin) {
    if (_showError && pin.isEmpty) {
      setState(() {
        _showError = false;
        _errorMessage = null;
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
        backgroundColor: Theme.of(context).cardColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Delete your Account',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
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
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                vSpace(12),
                Text(
                  'Enter your transaction PIN to confirm deleting of your account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      hSpace(8),
                      Text(
                        'Show PIN',
                        style: TextStyle(
                          fontSize: 15.sp,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        hSpace(12),
                        Expanded(
                          child: Text(
                            _errorMessage ?? 'Incorrect PIN entered, please try again',
                            style: TextStyle(
                              fontSize: 15.sp,
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

