import 'package:flutter/material.dart';
import 'package:communal_mobile/core/widgets/animated_logo_loader.dart';

/// Full-screen dimming layer + loader. Blocks taps to widgets below (use inside [Stack] with [Positioned.fill]).
class LoaderOverlay extends StatelessWidget {
  const LoaderOverlay({super.key, this.loaderSize = 52});

  final double loaderSize;

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      child: Material(
        color: Colors.black,
        child: SizedBox.expand(
          child: Center(
            child: AnimatedLogoLoader(size: loaderSize),
          ),
        ),
      ),
    );
  }
}

