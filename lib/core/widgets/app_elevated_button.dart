import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'apptext.dart';

class AppElevatedButton extends StatelessWidget {
  const AppElevatedButton({
    super.key,
    this.onPressed,
    this.title,
    this.child,
    this.isLoading = false,
    this.loadingLabel,
  });

  final void Function()? onPressed;
  final String? title;
  final Widget? child;
  final bool isLoading;
  /// Shown next to the spinner when [isLoading] is true (e.g. "Submitting…").
  final String? loadingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: AbsorbPointer(
        absorbing: isLoading,
        child: Opacity(
          opacity: isLoading ? 0.7 : 1.0,
      child: ElevatedButton(
            onPressed: isLoading ? () {} : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
              // Disabled = primary tinted lighter (alpha 0.45). Looks
              // like a light overlay sits on top of the brand colour
              // — keeps the action visually identifiable while
              // signalling "not ready" instead of going pure white.
              disabledBackgroundColor:
                  theme.primaryColor.withValues(alpha: 0.45),
              disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25.r),
          ),
          // Use minimumSize instead of a fixed-height SizedBox so
          // the button can grow on short screens rather than clipping
          // its text. 52.w uses width-based scaling which stays stable
          // in portrait regardless of device height.
          minimumSize: Size(double.infinity, 52.w),
          padding: EdgeInsets.symmetric(vertical: 14.w),
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 22.w,
                    height: 22.w,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  // Pass loadingLabel: '' for a spinner-only button.
                  if (loadingLabel != '') ...[
                    SizedBox(width: 12.w),
                    Flexible(
                      child: Text(
                        loadingLabel ?? 'Please wait…',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ],
              )
            : (child ??
            Text(
              title ?? "",
              style: TextStyle(
                color: Colors.white,
                fontSize: 19.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                  ),
                )),
              ),
            ),
      ),
    );
  }
}

class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({
    super.key,
    this.onPressed,
    required this.title,
    this.child,
  });

  final void Function()? onPressed;
  final String title;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.brightness == Brightness.dark
        ? Colors.white
        : theme.primaryColor;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(width: 1.0, color: color),
        minimumSize: Size(double.infinity, 50.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
      child:
          child ??
          SmallAppText(
            title,
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 19.sp,
          ),
    );
  }
}

class AppSecondaryButton extends StatelessWidget {
  const AppSecondaryButton({
    super.key,
    this.onPressed,
    required this.title,
    this.child,
    this.isDark = true, // true for dark bg (white border), false → derive from theme
  });

  final void Function()? onPressed;
  final String title;
  final Widget? child;

  /// `true` forces the white-on-dark style (use on screens with a fixed
  /// dark image background like the welcome splash). `false` lets the
  /// active theme drive the border + text colour, so the button reads
  /// correctly on light *and* dark scaffolds.
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color borderColor;
    final Color textColor;
    if (isDark) {
      // Forced white-on-dark style for screens with a fixed dark image
      // background (welcome splash, etc.).
      borderColor = Colors.white;
      textColor = Colors.white;
    } else {
      // Theme-driven secondary: white in dark mode (so the outline
      // reads against a dark scaffold), brand purple in light mode.
      final isDarkTheme = theme.brightness == Brightness.dark;
      borderColor = isDarkTheme ? Colors.white : theme.primaryColor;
      textColor = isDarkTheme ? Colors.white : theme.primaryColor;
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            width: 1.5,
            color: borderColor,
          ),
          backgroundColor: Colors.transparent,
          // Material 3 OutlinedButton paints a `surfaceTint` overlay
          // by default; on a dark scaffold this rendered the button
          // body as a near-white block. Pinning these to transparent
          // keeps the button truly outlined-only.
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25.r),
          ),
          minimumSize: Size(double.infinity, 52.w),
          padding: EdgeInsets.symmetric(vertical: 14.w),
        ),
        child:
            child ??
            Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: 19.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
      ),
    );
  }
}