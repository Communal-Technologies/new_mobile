import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/numeric_keypad.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/loader_overlay.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:go_router/go_router.dart';

class ChangeLoginPinScreen extends StatefulWidget {
  const ChangeLoginPinScreen({super.key});

  @override
  State<ChangeLoginPinScreen> createState() => _ChangeLoginPinScreenState();
}

class _ChangeLoginPinScreenState extends State<ChangeLoginPinScreen> {
  final _repo = getIt<AuthRepository>();

  // Phase 0 = current PIN, phase 1 = new PIN, phase 2 = confirm new PIN
  int _phase = 0;
  String _currentPin = '';
  String _newPin = '';
  String _confirmPin = '';
  String? _errorMessage;
  bool _isSubmitting = false;
  bool _isSuccess = false;
  bool _isPinVisible = false;

  String get _activePin {
    if (_phase == 0) return _currentPin;
    if (_phase == 1) return _newPin;
    return _confirmPin;
  }

  void _set(String v) {
    setState(() {
      if (_phase == 0) {
        _currentPin = v;
      } else if (_phase == 1) {
        _newPin = v;
      } else {
        _confirmPin = v;
      }
      _errorMessage = null;
    });
  }

  void _onNumberTap(String number) {
    if (_isSubmitting || _isSuccess) return;
    final pin = _activePin;
    if (pin.length < 6) {
      _set(pin + number);
      if (_activePin.length == 6) {
        Future.delayed(const Duration(milliseconds: 300), _advance);
      }
    }
  }

  void _onBackspace() {
    if (_isSubmitting || _isSuccess) return;
    final pin = _activePin;
    if (pin.isNotEmpty) _set(pin.substring(0, pin.length - 1));
  }

  Future<void> _advance() async {
    if (_phase == 0) {
      if (_currentPin.length != 6) return;
      setState(() {
        _phase = 1;
        _errorMessage = null;
      });
      return;
    }

    if (_phase == 1) {
      // Basic strength check
      final pin = _newPin;
      final firstChar = pin[0];
      if (pin.split('').every((c) => c == firstChar)) {
        setState(() {
          _errorMessage = 'PIN cannot be all the same digit. Choose a stronger PIN.';
          _newPin = '';
        });
        return;
      }
      setState(() {
        _phase = 2;
        _errorMessage = null;
      });
      return;
    }

    // Phase 2: confirm and submit
    if (_confirmPin != _newPin) {
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _phase = 1;
        _newPin = '';
        _confirmPin = '';
      });
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _repo.changeLoginPin(_currentPin, _newPin);
      if (!mounted) return;
      setState(() {
        _isSuccess = true;
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _isSubmitting = false;
        _errorMessage = msg;
        // If old PIN was wrong, restart from the beginning
        if (msg.toLowerCase().contains('incorrect') ||
            msg.toLowerCase().contains('old password') ||
            msg.toLowerCase().contains('current')) {
          _phase = 0;
          _currentPin = '';
          _newPin = '';
          _confirmPin = '';
        } else {
          // New PIN validation error — go back to new PIN entry
          _phase = 1;
          _newPin = '';
          _confirmPin = '';
        }
      });
    }
  }

  String get _title {
    if (_isSuccess) return 'PIN Changed';
    if (_phase == 0) return 'Current PIN';
    if (_phase == 1) return 'New PIN';
    return 'Confirm PIN';
  }

  String get _subtitle {
    if (_isSuccess) return 'Your login PIN has been updated successfully.';
    if (_phase == 0) return 'Enter your current 6-digit login PIN';
    if (_phase == 1) return 'Create a new 6-digit login PIN';
    return 'Re-enter your new 6-digit PIN to confirm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _isSubmitting
                  ? null
                  : () {
                      if (_phase > 0 && !_isSuccess) {
                        setState(() {
                          _errorMessage = null;
                          if (_phase == 2) {
                            _confirmPin = '';
                            _phase = 1;
                          } else {
                            _newPin = '';
                            _phase = 0;
                          }
                        });
                      } else {
                        context.pop();
                      }
                    },
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                children: [
                  vSpace(10),
                  Center(
                    child: Image.asset(
                      theme.brightness == Brightness.dark
                          ? Images.whiteLogo
                          : Images.coloredLogo,
                      width: 130.w,
                    ),
                  ),
                  vSpace(24),
                  Center(
                    child: Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isSuccess
                            ? const Color(0xFF1AAE70).withValues(alpha: 0.12)
                            : theme.primaryColor.withValues(alpha: 0.12),
                      ),
                      child: Icon(
                        _isSuccess ? Icons.check_circle : Icons.lock_outline,
                        size: 40.sp,
                        color: _isSuccess
                            ? const Color(0xFF1AAE70)
                            : theme.primaryColor,
                      ),
                    ),
                  ),
                  vSpace(16),
                  Center(
                    child: Text(
                      _title,
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  vSpace(6),
                  Center(
                    child: Text(
                      _subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17.sp,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  vSpace(32),
                  if (!_isSuccess) ...[
                    // 6-dot PIN indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(6, (index) {
                        final hasValue = index < _activePin.length;
                        final hasError = _errorMessage != null;
                        return Flexible(
                          child: GestureDetector(
                            onTap: () {
                              if (_activePin.isNotEmpty) {
                                setState(() => _isPinVisible = !_isPinVisible);
                              }
                            },
                            child: Container(
                              width: 40.w,
                              height: 40.w,
                              margin: EdgeInsets.symmetric(horizontal: 3.w),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasValue
                                    ? (hasError ? Colors.red : theme.primaryColor)
                                    : theme.colorScheme.onSurface
                                        .withValues(alpha: 0.08),
                                border: Border.all(
                                  color: hasError
                                      ? Colors.red
                                      : (hasValue
                                          ? theme.primaryColor
                                          : theme.dividerColor),
                                  width: hasError ? 2 : 1.5,
                                ),
                              ),
                              child: hasValue
                                  ? Center(
                                      child: _isPinVisible
                                          ? Text(
                                              _activePin[index],
                                              style: TextStyle(
                                                fontSize: 19.sp,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Container(
                                              width: 12.w,
                                              height: 12.w,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Colors.white,
                                              ),
                                            ),
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                    if (_errorMessage != null) ...[
                      vSpace(12),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          fontSize: 17.sp,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    vSpace(32),
                    NumericKeypad(
                      onNumberTap: _onNumberTap,
                      onBackspace: _onBackspace,
                    ),
                    vSpace(20),
                  ] else ...[
                    vSpace(20),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1AAE70).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline,
                              color: const Color(0xFF1AAE70), size: 20.sp),
                          hSpace(10),
                          Expanded(
                            child: Text(
                              'Use your new PIN the next time you sign in.',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    vSpace(32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    vSpace(20),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (_isSubmitting)
          Positioned.fill(child: const LoaderOverlay()),
      ],
    );
  }
}
