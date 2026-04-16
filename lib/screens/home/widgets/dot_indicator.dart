import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DotIndicator extends StatelessWidget {
  final bool isActive;
  final ThemeData theme;

  const DotIndicator({
    super.key,
    required this.isActive,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isActive ? 20.w : 6.w,
      height: 6.h,
      decoration: BoxDecoration(
        color: isActive ? theme.primaryColor : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(3.r),
      ),
    );
  }
}

