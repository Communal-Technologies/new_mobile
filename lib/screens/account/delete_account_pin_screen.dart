import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/account_actions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/account/delete_account_request.dart';
import 'package:communal_mobile/screens/account/widgets/pin_input_field.dart';

class DeleteAccountPinScreen extends StatefulWidget {
  const DeleteAccountPinScreen({super.key, required this.request});

  final DeleteAccountRequest request;

  @override
  State<DeleteAccountPinScreen> createState() =>
      _DeleteAccountPinScreenState();
}

class _DeleteAccountPinScreenState extends State<DeleteAccountPinScreen> {
  bool _obscurePin = true;
  bool _showError = false;
  bool _submitting = false;
  String? _errorMessage;

  /// Verifying and deleting live in the same handler on purpose. The PIN mints a
  /// short-lived marker in shared Redis that the delete endpoint consumes, so
  /// there is no step in between where a verified PIN sits around unspent.
  ///
  /// Every checkpoint is re-run by the server here, against the state of the
  /// account at this moment rather than the preview the flow started from — a
  /// 409 means something changed while the user was reading the warnings.
  Future<void> _handlePinCompleted(String pin) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _showError = false;
      _errorMessage = null;
    });
    final auth = context.read<AuthBloc>();
    try {
      final repository = getIt<AccountActionsRepository>();
      await repository.verifySecurityPin(pin, intent: 'account-action');
      await repository.deleteAccount(
        confirmation: widget.request.confirmation,
        reason: widget.request.reason,
      );
      if (!mounted) return;
      // Leave the flow before signing out: the credentials are already dead
      // server-side, and the success screen is the one place the app can still
      // stand without a session.
      context.goNamed('delete-account-success');
      auth.add(LogoutRequested());
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
                  'Enter your transaction PIN. Your account is deleted as soon '
                  'as the PIN is accepted.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17.sp,
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
                if (_submitting) ...[
                  vSpace(24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 16.sp,
                        width: 16.sp,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                      hSpace(12),
                      Text(
                        'Deleting your account…',
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ],
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
                          fontSize: 17.sp,
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
                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFFD32F2F).withValues(alpha: 0.16) : const Color(0xFFFFEBEE),
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
                                fontSize: 17.sp,
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
                              fontSize: 17.sp,
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

