import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shared text-field decoration used across the bill-payment form
/// screens. Lives here so the dark-mode fix (theme-aware fill +
/// borders) doesn't need to be re-applied in 4 places when the design
/// shifts.
InputDecoration billInputDecoration(BuildContext context, String hint) {
  final theme = Theme.of(context);
  return InputDecoration(
    hintText: hint,
    filled: true,
    // Theme-aware: stays light grey on light, sits on the surface
    // container in dark mode instead of glowing white.
    fillColor: theme.colorScheme.surfaceContainerHighest,
    hintStyle: TextStyle(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: BorderSide(color: theme.dividerColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: BorderSide(color: theme.dividerColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14.r),
      borderSide: const BorderSide(color: Color(0xFF7434FF), width: 1.5),
    ),
  );
}
