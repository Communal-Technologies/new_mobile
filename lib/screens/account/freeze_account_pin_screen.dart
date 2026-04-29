import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/account_actions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/account/widgets/pin_input_field.dart';

class FreezeAccountPinScreen extends StatefulWidget {
  const FreezeAccountPinScreen({super.key, this.reason});

  /// Reason text passed from freeze_account_screen. Defaults to a
  /// generic reason if the user didn't supply one — the backend
  /// requires ≥ 10 chars.
  final String? reason;

  @override
  State<FreezeAccountPinScreen> createState() => _FreezeAccountPinScreenState();
}

class _FreezeAccountPinScreenState extends State<FreezeAccountPinScreen> {
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
    final repo = getIt<AccountActionsRepository>();
    try {
      await repo.verifySecurityPin(pin);
      final reason = (widget.reason?.trim().isNotEmpty == true)
          ? widget.reason!.trim()
          : 'Self-frozen via mobile app';
      await repo.freezeAccount(reason);
      if (!mounted) return;
      // Auth state needs to learn about the freeze — auth_status_notifier
      // gates protected routes off the user's wallet status.
      context.read<AuthBloc>().add(AuthRefreshUserRequested());
      context.pushReplacementNamed('freeze-account-success');
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
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Freeze Account',
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
            margin: EdgeInsets.all(16.w),
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20.r),
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
                  'Enter your transaction PIN to confirm freezing of your account',
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
                        _obscurePin ? Icons.visibility_outlined : Icons.visibility_off_outlined,
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
                        Icon(
                          Icons.error_outline,
                          color: const Color(0xFFD32F2F),
                          size: 20.sp,
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
