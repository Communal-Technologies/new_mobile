import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/transfer_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class ChangeTransactionPinScreen extends StatefulWidget {
  const ChangeTransactionPinScreen({super.key});

  @override
  State<ChangeTransactionPinScreen> createState() =>
      _ChangeTransactionPinScreenState();
}

class _ChangeTransactionPinScreenState extends State<ChangeTransactionPinScreen> {
  final _repo = getIt<TransferRepository>();
  final _pinCtrl = TextEditingController();
  final _pinFocus = FocusNode();

  bool _showPin = false;
  bool _submitting = false;
  bool _isSuccess = false;
  String? _errorText;

  String _currentPin = '';
  String _newPin = '';
  String _confirmPin = '';
  static const Set<String> _blockedPins = {
    '0000',
    '1111',
    '2222',
    '3333',
    '4444',
    '5555',
    '6666',
    '7777',
    '8888',
    '9999',
    '1234',
    '4321',
    '1212',
    '1122',
    '1000',
    '2000',
    '3000',
    '6969',
    '2580',
  };

  bool get _hasExistingPin {
    final auth = context.read<AuthBloc>().state;
    return auth is AuthAuthenticated ? auth.user.hasSecurityPin : false;
  }

  int get _phase {
    if (_isSuccess) return 3;
    if (_hasExistingPin) {
      if (_currentPin.isEmpty) return 0;
      if (_newPin.isEmpty) return 1;
      return 2;
    }
    if (_newPin.isEmpty) return 1;
    return 2;
  }

  String get _titleText {
    if (_isSuccess) return 'PIN Changed Successfully';
    if (_hasExistingPin) {
      if (_phase == 0) return 'Enter Current PIN';
      if (_phase == 1) return 'Enter New PIN';
      return 'Confirm New PIN';
    }
    if (_phase == 1) return 'Enter New PIN';
    return 'Confirm New PIN';
  }

  String get _subtitleText {
    if (_isSuccess) {
      return 'Your transaction pin has been updated. Use your new pin for all future transactions.';
    }
    if (_hasExistingPin && _phase == 0) {
      return 'Enter your current 4-digit transaction PIN';
    }
    if (_phase == 1) return 'Create a new 4-digit transaction PIN';
    return 'Confirm your new 4-digit transaction PIN';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPinFocus());
  }

  @override
  void dispose() {
    _pinCtrl.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  void _requestPinFocus() {
    if (!mounted || _isSuccess) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isSuccess) return;
      FocusScope.of(context).requestFocus(_pinFocus);
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  bool _canContinue() => !_submitting && _pinCtrl.text.trim().length == 4;

  bool _isObviousPin(String pin) {
    if (pin.length != 4) return false;
    if (_blockedPins.contains(pin)) return true;
    if (RegExp(r'^(\d)\1{3}$').hasMatch(pin)) return true; // 1111
    final digits = pin.split('').map(int.parse).toList(growable: false);
    final asc = List.generate(4, (i) => digits[0] + i);
    final desc = List.generate(4, (i) => digits[0] - i);
    final isAsc = List.generate(4, (i) => digits[i] == asc[i]).every((v) => v);
    final isDesc =
        List.generate(4, (i) => digits[i] == desc[i]).every((v) => v);
    return isAsc || isDesc; // 1234 / 4321 / 6789 / 9876
  }

  Future<void> _onContinue() async {
    if (_isSuccess) {
      context.pop();
      return;
    }
    if (!_canContinue()) return;

    final input = _pinCtrl.text.trim();
    setState(() {
      _errorText = null;
    });

    if (_hasExistingPin && _phase == 0) {
      setState(() => _submitting = true);
      try {
        await _repo.verifySecurityPin(input);
        if (!mounted) return;
        setState(() {
          _currentPin = input;
          _pinCtrl.clear();
        });
        _requestPinFocus();
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _errorText = 'Incorrect PIN entered, please try again';
        });
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
      return;
    }

    if (_phase == 1) {
      if (_isObviousPin(input)) {
        setState(() {
          _errorText =
              'This PIN is too easy to guess. Choose a less obvious 4-digit PIN.';
        });
        return;
      }
      setState(() {
        _newPin = input;
        _pinCtrl.clear();
      });
      _requestPinFocus();
      return;
    }

    setState(() => _submitting = true);
    try {
      if (input != _newPin) {
        setState(() {
          _errorText = 'PINs do not match, please try again';
          _newPin = '';
          _confirmPin = '';
          _pinCtrl.clear();
        });
        _requestPinFocus();
        return;
      }
      _confirmPin = input;
      await _repo.updateSecurityPin(_confirmPin);
      if (!mounted) return;
      context.read<AuthBloc>().add(AuthRefreshUserRequested());
      setState(() {
        _isSuccess = true;
        _errorText = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final secondFilled = !_isSuccess && (_phase >= 2 || _pinCtrl.text.length == 4);
    final thirdFilled = _isSuccess;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 22),
          onPressed: () => context.pop(),
        ),
        title: const Text('Change your PIN'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Row(
              children: [
                _bar(true, primary),
                hSpace(6),
                _bar(secondFilled, primary),
                hSpace(6),
                _bar(thirdFilled, primary),
              ],
            ),
            vSpace(22),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: Stack(
                children: [
                  if (!_isSuccess &&
                      ((_hasExistingPin && _phase > 0) ||
                          (!_hasExistingPin && _phase > 1)))
                    Positioned(
                      top: 6.h,
                      left: 8.w,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: _submitting
                            ? null
                            : () {
                                setState(() {
                                  _errorText = null;
                                  _pinCtrl.clear();
                                  if (_phase == 2) {
                                    _newPin = '';
                                    _confirmPin = '';
                                  } else if (_phase == 1 && _hasExistingPin) {
                                    _currentPin = '';
                                  }
                                });
                                _requestPinFocus();
                              },
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          size: 14.sp,
                          color: Theme.of(context).primaryColor,
                        ),
                        label: Text(
                          'Go back',
                          style: TextStyle(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      children: [
                        Container(
                          width: 56.w,
                          height: 56.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (_isSuccess ? const Color(0xFF1AAE70) : primary)
                                .withValues(alpha: 0.10),
                          ),
                          child: Icon(
                            _isSuccess ? Icons.check_circle : Icons.lock_outline,
                            color: _isSuccess ? const Color(0xFF1AAE70) : primary,
                            size: 30.sp,
                          ),
                        ),
                        vSpace(14),
                        Text(
                          _titleText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        vSpace(6),
                        Text(
                          _subtitleText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17.sp,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                  if (!_isSuccess) ...[
                    vSpace(16),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _requestPinFocus,
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(4, (i) {
                            final filled = i < _pinCtrl.text.length;
                            return Container(
                              width: 58.w,
                              height: 58.w,
                              margin: EdgeInsets.symmetric(horizontal: 4.w),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(8.r),
                                border: Border.all(
                                  color:
                                      filled ? primary : const Color(0xFFD9D9D9),
                                  width: 1.6,
                                ),
                              ),
                              child: Text(
                                filled
                                    ? (_showPin ? _pinCtrl.text[i] : '*')
                                    : '',
                                style: TextStyle(
                                  color: primary,
                                  fontSize: 22.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    SizedBox(
                      width: 0,
                      height: 0,
                      child: TextField(
                        controller: _pinCtrl,
                        focusNode: _pinFocus,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        autofocus: false,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    vSpace(10),
                    InkWell(
                      onTap: () => setState(() => _showPin = !_showPin),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _showPin ? Icons.visibility_off : Icons.visibility,
                            size: 18.sp,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          hSpace(6),
                          Text(
                            'Show PIN',
                            style: TextStyle(
                              fontSize: 17.sp,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_errorText != null) ...[
                      vSpace(10),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 9.h,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFC62828).withValues(alpha: 0.16)
                              : const Color(0xFFFFE3E2),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 18.sp,
                              color: const Color(0xFFC62828),
                            ),
                            hSpace(8),
                            Expanded(
                              child: Text(
                                _errorText!,
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  color: const Color(0xFFC62828),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ] else ...[
                    vSpace(14),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: primary, size: 18.sp),
                          hSpace(8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Security Tip',
                                  style: TextStyle(
                                    fontSize: 17.sp,
                                    fontWeight: FontWeight.w700,
                                    color: primary,
                                  ),
                                ),
                                vSpace(3),
                                Text(
                                  'Never share your PIN wth anyone.\nCommunal HQ will never ask for your PIN via email, SMS or phone call.',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            vSpace(12),
            if (!_isSuccess)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF06FDF9).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PIN Security Tips',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    vSpace(8),
                    _bullet('Avoid using obvious number (1234, 0000)'),
                    _bullet("Don't use your birthday or phone number"),
                    _bullet('Choose a PIN you can remember easily'),
                    _bullet('Never share your PIN with any one.'),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
        child: SizedBox(
          width: double.infinity,
          height: 50.h,
          child: InkWell(
            onTap: (_canContinue() || _isSuccess) && !_submitting ? _onContinue : null,
            borderRadius: BorderRadius.circular(12.r),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                color: (_canContinue() || _isSuccess)
                    ? null
                    : const Color(0xFFE0E0E0),
                gradient: (_canContinue() || _isSuccess)
                    ? const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [Color(0xFF8C66F5), Color(0xFF6A39F3)],
                      )
                    : null,
              ),
              child: Center(
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _isSuccess ? 'Done' : 'Continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bar(bool filled, Color primary) {
    return Expanded(
      child: Container(
        height: 6.h,
        decoration: BoxDecoration(
          color: filled ? primary : const Color(0xFFE1E1E1),
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          hSpace(8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5.sp,
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
