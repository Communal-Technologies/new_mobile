import 'package:communal_mobile/core/constants/images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AnimatedLogoLoader extends StatefulWidget {
  const AnimatedLogoLoader({super.key, this.size = 56});

  final double size;

  @override
  State<AnimatedLogoLoader> createState() => _AnimatedLogoLoaderState();
}

class _AnimatedLogoLoaderState extends State<AnimatedLogoLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Image.asset(
        Images.loader,
        width: widget.size.w,
        height: widget.size.w,
        fit: BoxFit.contain,
      ),
    );
  }
}
