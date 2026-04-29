import 'package:flutter/material.dart';
import 'package:communal_mobile/core/constants/images.dart';

/// Full-screen tap shield + centered loader.
///
/// The loader icon zoom-pulses continuously. Previously this widget just
/// rendered an `Image.asset` of `loader.gif` and relied on Flutter's
/// built-in GIF playback to provide motion — that worked inconsistently
/// on some devices, leaving a static icon during auth-in-progress. The
/// explicit [ScaleTransition] guarantees the pulse regardless of GIF
/// decoder behaviour.
///
/// Default scrim is a light dark dim. Set [scrimColor] for a frosted /
/// soft veil (e.g. off-white at low opacity) instead of black.
class LoaderOverlay extends StatefulWidget {
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
  State<LoaderOverlay> createState() => _LoaderOverlayState();
}

class _LoaderOverlayState extends State<LoaderOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.82, end: 1.18).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color scrim = widget.scrimColor ??
        Colors.black.withValues(alpha: widget.scrimAlpha.clamp(0.0, 1.0));
    // The loader.gif is a coloured asset whose dark glyphs vanish on
    // a dark scrim. We don't ship a separate white loader; instead,
    // tint the existing GIF white in dark mode via a srcIn blend so
    // the silhouette stays visible while the pulse animation keeps
    // running. Light mode keeps the original colours.
    final Image loaderImage = Image.asset(
      Images.loader,
      width: widget.loaderSize,
      height: widget.loaderSize,
      fit: BoxFit.contain,
      color: isDark ? Colors.white : null,
      colorBlendMode: isDark ? BlendMode.srcIn : null,
    );
    return AbsorbPointer(
      child: ColoredBox(
        color: scrim,
        child: SizedBox.expand(
          child: Center(
            child: ScaleTransition(
              scale: _scale,
              child: loaderImage,
            ),
          ),
        ),
      ),
    );
  }
}
