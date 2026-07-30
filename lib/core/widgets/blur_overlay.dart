import 'dart:ui';
import 'package:flutter/material.dart';

/// A blur overlay widget that covers the entire screen
class BlurOverlay extends StatelessWidget {
  const BlurOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    // Must not wrap in [Positioned] here — parent [Stack] uses [Positioned.fill] + [GestureDetector].
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black.withOpacity(0.3),
      ),
    );
  }
}

