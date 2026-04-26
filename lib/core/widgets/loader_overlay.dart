import 'package:flutter/material.dart';
import 'package:communal_mobile/core/constants/images.dart';

/// Full-screen tap shield + centered loader.
///
/// Default scrim is a light dark dim. Set [scrimColor] for a frosted / soft veil
/// (e.g. off-white at low opacity) instead of black.
class LoaderOverlay extends StatelessWidget {
  const LoaderOverlay({
    super.key,
    this.loaderSize = 52,
    this.scrimAlpha = 0.4,
    this.scrimColor,
  });

  final double loaderSize;

  /// Opacity of the dark scrim when [scrimColor] is null (0 = invisible, 1 = solid black).
  final double scrimAlpha;

  /// When set, overrides [scrimAlpha] / black dim (e.g. `Color(0x99E8E8E8)`).
  final Color? scrimColor;

  @override
  Widget build(BuildContext context) {
    final Color scrim = scrimColor ??
        Colors.black.withValues(alpha: scrimAlpha.clamp(0.0, 1.0));
    return AbsorbPointer(
      child: ColoredBox(
        color: scrim,
        child: SizedBox.expand(
          child: Center(
            child: Image.asset(
              Images.loader,
              width: loaderSize,
              height: loaderSize,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
