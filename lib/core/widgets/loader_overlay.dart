import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';

/// Full-screen dimming layer + loader. Blocks taps to widgets below (use inside [Stack] with [Positioned.fill]).
class LoaderOverlay extends StatelessWidget {
  const LoaderOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        child: SizedBox.expand(
          child: Center(
            child: Image.asset(
              Images.loader,
              width: 80.w,
              height: 80.w,
            ),
          ),
        ),
      ),
    );
  }
}

