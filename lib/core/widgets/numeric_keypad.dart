import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

/// A reusable numeric keypad widget
class NumericKeypad extends StatelessWidget {
  const NumericKeypad({
    super.key,
    required this.onNumberTap,
    required this.onBackspace,
    this.keySize = 70,
    this.rowSpacing = 12,
    this.bottomLeftIcon,
    this.onBottomLeft,
    this.bottomLeftColor,
  });

  final ValueChanged<String> onNumberTap;
  final VoidCallback onBackspace;

  /// Diameter of each round key, in design pixels.
  final double keySize;
  final double rowSpacing;

  /// An optional key in the otherwise empty bottom-left cell — a biometric
  /// shortcut on the payment PIN screens.
  final IconData? bottomLeftIcon;
  final VoidCallback? onBottomLeft;
  final Color? bottomLeftColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Row 1: 1, 2, 3
        _buildKeypadRow(['1', '2', '3'], theme),
        vSpace(rowSpacing),
        // Row 2: 4, 5, 6
        _buildKeypadRow(['4', '5', '6'], theme),
        vSpace(rowSpacing),
        // Row 3: 7, 8, 9
        _buildKeypadRow(['7', '8', '9'], theme),
        vSpace(rowSpacing),
        // Row 4: empty (or the bottom-left key), 0, Backspace
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (bottomLeftIcon != null && onBottomLeft != null)
              _buildKeypadButton(
                icon: bottomLeftIcon,
                iconColor: bottomLeftColor,
                onTap: onBottomLeft!,
                theme: theme,
              )
            else
              SizedBox(width: keySize.w, height: keySize.w),
            _buildKeypadButton(
              label: '0',
              onTap: () => onNumberTap('0'),
              theme: theme,
            ),
            _buildKeypadButton(
              icon: Icons.backspace_outlined,
              onTap: onBackspace,
              theme: theme,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> numbers, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: numbers
          .map((number) => _buildKeypadButton(
                label: number,
                onTap: () => onNumberTap(number),
                theme: theme,
              ))
          .toList(),
    );
  }

  Widget _buildKeypadButton({
    String? label,
    IconData? icon,
    Color? iconColor,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50.r),
      child: Container(
        width: keySize.w,
        height: keySize.w,
        decoration: BoxDecoration(
          // Read the live theme so the keypad keys flip with the
          // dark/light toggle. `surfaceContainerHighest` gives the
          // softer "raised pill" tint Material 3 ships for both
          // themes, instead of the hardcoded Colors.grey.shade100
          // that rendered as a near-white bg on a dark scaffold.
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(50.r),
        ),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  size: iconColor != null ? 28.sp : 24.sp,
                  color: iconColor ?? theme.colorScheme.onSurface,
                )
              : Text(
                  label!,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
        ),
      ),
    );
  }
}
