import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/otp_input_field.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/profile_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/account/widgets/pin_input_field.dart';

/// The email address and phone number the account signs in with.
///
/// Read-only here, and changed one at a time, because these two are not details —
/// they are the credentials. Every password reset and every login code is sent to
/// them, so `update-profile` refuses a changed one: the change is authorised with
/// the transaction PIN and confirmed with a code sent to the new value, and the
/// server warns the address being replaced so a change nobody asked for is visible
/// to whoever still holds the old one.
class SignInDetailsSection extends StatelessWidget {
  const SignInDetailsSection({
    super.key,
    required this.email,
    required this.phone,
    required this.onChanged,
  });

  final String email;
  final String phone;

  /// Called with the field ('email' or 'phone') and the value as stored once a
  /// change completes, so the caller can show it without a round trip.
  final void Function(String field, String value) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_outline,
                color: theme.colorScheme.primary,
                size: 20.sp,
              ),
              hSpace(8),
              Text(
                'Sign-in Details',
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          vSpace(6),
          Text(
            'What you sign in with, and where your codes are sent.',
            style: TextStyle(
              fontSize: 15.sp,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          vSpace(16),
          _ContactRow(
            icon: Icons.email_outlined,
            label: 'Email Address',
            value: email,
            onChange: () => _startChange(context, 'email', email),
          ),
          vSpace(12),
          _ContactRow(
            icon: Icons.phone_outlined,
            label: 'Phone Number',
            value: phone,
            onChange: () => _startChange(context, 'phone', phone),
          ),
        ],
      ),
    );
  }

  Future<void> _startChange(
    BuildContext context,
    String field,
    String current,
  ) async {
    final changed = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (_) => _ContactChangeSheet(field: field, current: current),
    );
    if (changed != null && changed.isNotEmpty) onChanged(field, changed);
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChange,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 18.sp,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        hSpace(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              Text(
                value.isEmpty ? 'Not provided' : value,
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: value.isEmpty
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onChange,
          child: Text(
            'Change',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// The two steps of a contact change: nominate and prove, then confirm the code.
class _ContactChangeSheet extends StatefulWidget {
  const _ContactChangeSheet({required this.field, required this.current});

  final String field;
  final String current;

  @override
  State<_ContactChangeSheet> createState() => _ContactChangeSheetState();
}

class _ContactChangeSheetState extends State<_ContactChangeSheet> {
  final _formKey = GlobalKey<FormState>();
  final _valueController = TextEditingController();

  String _pin = '';
  String _code = '';
  String? _error;
  bool _busy = false;
  ContactChangeStarted? _started;

  bool get _isEmail => widget.field == 'email';
  String get _label => _isEmail ? 'email address' : 'phone number';

  @override
  void dispose() {
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_pin.length != 4) {
      setState(() => _error = 'Enter your 4-digit transaction PIN.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final started = await getIt<ProfileRepository>().requestContactChange(
        field: widget.field,
        value: _valueController.text.trim(),
        securityPin: _pin,
      );
      if (!mounted) return;
      setState(() {
        _started = started;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _confirm() async {
    if (_code.length < 4) {
      setState(() => _error = 'Enter the code we sent you.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final stored =
          await getIt<ProfileRepository>().verifyContactChange(_code);
      if (!mounted) return;
      Navigator.of(context).pop(
        stored.isEmpty ? _valueController.text.trim() : stored,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text('Your $_label has been changed.'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final started = _started;

    return Padding(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 12.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            vSpace(16),
            Text(
              'Change your $_label',
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
            ),
            vSpace(8),
            Text(
              started == null
                  ? 'We will send a code to the new $_label to confirm you can reach it. Nothing changes until you enter it.'
                  : 'We sent a code to ${started.sentTo}. It expires in ${started.expiresInMinutes} minutes.',
              style: TextStyle(
                fontSize: 15.sp,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            if (_error != null) ...[
              vSpace(12),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
            vSpace(20),
            if (started == null)
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _valueController,
                      keyboardType: _isEmail
                          ? TextInputType.emailAddress
                          : TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'New ${_isEmail ? 'Email Address' : 'Phone Number'}',
                        helperText: _isEmail
                            ? null
                            : 'Nigerian numbers are stored as 0801…',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      validator: (value) {
                        final v = (value ?? '').trim();
                        if (v.isEmpty) return 'Enter the new $_label.';
                        if (_isEmail && !v.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        if (!_isEmail && v.replaceAll(RegExp(r'\D'), '').length < 7) {
                          return 'Please enter a valid phone number';
                        }
                        if (v.toLowerCase() == widget.current.trim().toLowerCase()) {
                          return 'That is the $_label you already have.';
                        }
                        return null;
                      },
                    ),
                    vSpace(20),
                    Text(
                      'Transaction PIN',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    vSpace(4),
                    Text(
                      'The same 4-digit PIN you use to pay. It is what proves this change is you.',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    vSpace(12),
                    PinInputField(
                      autoFocus: false,
                      onChanged: (value) => _pin = value,
                      onCompleted: (value) => _pin = value,
                    ),
                  ],
                ),
              )
            else
              OtpInputField(
                length: 6,
                onChanged: (value) => _code = value,
                onCompleted: (value) => _code = value,
              ),
            vSpace(24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _busy ? null : (started == null ? _send : _confirm),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: _busy
                    ? SizedBox(
                        height: 16.sp,
                        width: 16.sp,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(started == null ? 'Send Code' : 'Confirm Change'),
              ),
            ),
            vSpace(8),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
