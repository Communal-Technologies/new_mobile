import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'apptext.dart';

class AppElevatedButton extends StatelessWidget {
  const AppElevatedButton({super.key, this.onPressed, this.title, this.child});

  final void Function()? onPressed;
  final String? title;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.primaryColor,
        foregroundColor: theme.colorScheme.onPrimary,
        minimumSize: Size(double.infinity, 50.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
      child:
          child ??
          SmallAppText(
            title ?? "",
            color: theme.colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 16.sp,
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

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(width: 1.0, color: theme.primaryColor),
        minimumSize: Size(double.infinity, 50.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
      child:
          child ??
          SmallAppText(
            title,
            color: theme.primaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 16.sp,
          ),
    );
  }
}
