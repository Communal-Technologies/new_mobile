import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/numeric_keypad.dart';
import 'package:communal_mobile/core/widgets/space.dart';

/// PIN entry for authorising a payment.
///
/// The welcome-back screen's filled circles and round keys, a size smaller so the
/// payment summary stays in view above it, with the biometric shortcut in the
/// keypad's empty corner. No text field sits behind it, so the system keyboard
/// never opens over the screen.
class TransactionPinPad extends StatelessWidget {
  const TransactionPinPad({
    super.key,
    required this.pin,
    required this.onDigit,
    required this.onBackspace,
    this.length = 4,
    this.onBiometric,
    this.biometricIcon = Icons.fingerprint,
    this.busy = false,
    this.hasError = false,
  });

  final String pin;
  final int length;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  /// Null hides the biometric key.
  final VoidCallback? onBiometric;
  final IconData biometricIcon;

  /// Greys the keys out and ignores taps while a submission is in flight.
  final bool busy;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fill = hasError ? Colors.red : theme.primaryColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(length, (i) {
            final filled = i < pin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 44.w,
              height: 44.w,
              margin: EdgeInsets.symmetric(horizontal: 7.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: filled
                    ? fill
                    : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                border: Border.all(
                  color: hasError
                      ? Colors.red
                      : (filled ? theme.primaryColor : theme.dividerColor),
                  width: hasError ? 2 : 1.5,
                ),
              ),
              child: filled
                  ? Center(
                      child: Container(
                        width: 12.w,
                        height: 12.w,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : null,
            );
          }),
        ),
        vSpace(24),
        AbsorbPointer(
          absorbing: busy,
          child: AnimatedOpacity(
            opacity: busy ? 0.45 : 1,
            duration: const Duration(milliseconds: 150),
            child: NumericKeypad(
              onNumberTap: onDigit,
              onBackspace: onBackspace,
              keySize: 62,
              rowSpacing: 10,
              bottomLeftIcon: onBiometric == null ? null : biometricIcon,
              onBottomLeft: onBiometric,
              bottomLeftColor: theme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }
}
