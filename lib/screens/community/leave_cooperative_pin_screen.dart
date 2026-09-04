import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:communal_mobile/core/widgets/biometric_action_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/account_actions_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/account/widgets/pin_input_field.dart';
import 'package:communal_mobile/screens/community/leave_cooperative_screen.dart';

/// The last gate before the request is filed: the PIN proves it is the member
/// holding the phone, then the request itself is submitted from here so a
/// verified PIN is never left sitting on a screen with nothing done with it.
class LeaveCooperativePinScreen extends StatefulWidget {
  const LeaveCooperativePinScreen({super.key, required this.request});

  final LeaveCooperativeRequest request;

  @override
  State<LeaveCooperativePinScreen> createState() =>
      _LeaveCooperativePinScreenState();
}

class _LeaveCooperativePinScreenState extends State<LeaveCooperativePinScreen> {
  bool _obscurePin = true;
  bool _submitting = false;
  String? _errorMessage;

  Future<void> _handlePinCompleted(String pin) async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await getIt<AccountActionsRepository>()
          .verifySecurityPin(pin, intent: 'account-action');
      await _submit();
    } catch (e) {
      _fail(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Runs once the action is authorised, by PIN or by biometrics — the server
  /// takes the same marker either way.
  Future<void> _submit() async {
    try {
      await getIt<AccountActionsRepository>().submitAccountClosure(
        cooperativeId: widget.request.location.id,
        reason: widget.request.reason,
      );
      if (!mounted) return;
      context.pushReplacementNamed(
        'leave-cooperative-submitted',
        extra: widget.request.location,
      );
    } catch (e) {
      _fail(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _errorMessage = message;
    });
  }

  void _handlePinChanged(String pin) {
    if (_errorMessage != null && pin.isEmpty) {
      setState(() => _errorMessage = null);
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
            onPressed: _submitting ? null : () => context.pop(),
          ),
          title: Text(
            'Confirm with your PIN',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(32.w),
            child: Column(
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7434FF).withValues(alpha: 0.1),
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
                  'Enter your transaction PIN to send your request to leave '
                  '${widget.request.location.name}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17.sp,
                    height: 1.5,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                vSpace(40),
                PinInputField(
                  obscureText: _obscurePin,
                  onCompleted: _handlePinCompleted,
                  onChanged: _handlePinChanged,
                ),
                vSpace(24),
                if (_submitting)
                  const CircularProgressIndicator()
                else
                  GestureDetector(
                    onTap: () => setState(() => _obscurePin = !_obscurePin),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _obscurePin
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18.sp,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        hSpace(8),
                        Text(
                          'Show PIN',
                          style: TextStyle(
                            fontSize: 17.sp,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                BiometricActionButton(
                  label: 'Leave ${widget.request.location.name}',
                  promptSubtitle: 'Use biometrics to send your request',
                  enabled: !_submitting,
                  onAuthorized: () {
                    setState(() {
                      _submitting = true;
                      _errorMessage = null;
                    });
                    return _submit();
                  },
                  onFailed: _fail,
                ),
                if (_errorMessage != null) ...[
                  vSpace(24),
                  Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFFD32F2F).withValues(alpha: 0.16)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 20.sp,
                          color: const Color(0xFFD32F2F),
                        ),
                        hSpace(12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(
                              fontSize: 17.sp,
                              height: 1.4,
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
