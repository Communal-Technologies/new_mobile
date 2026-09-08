import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Pull-to-refresh that opens a strip above the page instead of floating a
/// spinner over it.
///
/// Dragging down slides the content off the top of the screen and reveals the
/// scaffold background that was always behind it, carrying "Refreshing…" and a
/// small activity indicator. When the work finishes the strip closes and the
/// page is back where it was — nothing is ever drawn on top of the UI, so the
/// balance and the cards stay readable while they are being refreshed.
///
/// [child] is the whole page as one box, which is why this takes over the
/// scrolling: the strip has to be a sibling of the content inside the same
/// viewport for the drag to move both.
///
/// Android's default clamping physics does not overscroll, and without
/// overscroll there is nothing to reveal — so the physics here is bouncing on
/// both platforms. That is a deliberate change to how the dashboard scrolls
/// past its ends.
class RevealRefresh extends StatefulWidget {
  const RevealRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.label = 'Refreshing…',
  });

  /// Awaited to completion — the strip stays open until it returns, so it has
  /// to resolve even when a request fails.
  final Future<void> Function() onRefresh;

  final Widget child;
  final String label;

  @override
  State<RevealRefresh> createState() => _RevealRefreshState();
}

class _RevealRefreshState extends State<RevealRefresh> {
  static const double _triggerDistance = 92;
  static const double _revealExtent = 64;

  RefreshIndicatorMode? _lastMode;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(
          refreshTriggerPullDistance: _triggerDistance,
          refreshIndicatorExtent: _revealExtent,
          onRefresh: widget.onRefresh,
          builder: _buildStrip,
        ),
        SliverToBoxAdapter(child: widget.child),
      ],
    );
  }

  Widget _buildStrip(
    BuildContext context,
    RefreshIndicatorMode mode,
    double pulledExtent,
    double triggerDistance,
    double indicatorExtent,
  ) {
    // The pull passing the trigger point is the moment the gesture commits, and
    // it happens under the member's finger rather than on release — so it is
    // worth confirming by touch.
    if (mode == RefreshIndicatorMode.armed &&
        _lastMode != RefreshIndicatorMode.armed) {
      HapticFeedback.lightImpact();
    }
    _lastMode = mode;

    final theme = Theme.of(context);
    final progress = (pulledExtent / triggerDistance).clamp(0.0, 1.0);
    final settled =
        mode == RefreshIndicatorMode.armed ||
        mode == RefreshIndicatorMode.refresh ||
        mode == RefreshIndicatorMode.done;
    // Fade in with the drag so a short accidental pull shows almost nothing.
    final opacity = settled ? 1.0 : (progress * progress);

    return ClipRect(
      child: Center(
        child: Opacity(
          opacity: opacity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
              SizedBox(width: 8.w),
              settled
                  ? CupertinoActivityIndicator(
                      radius: 9.r,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.72,
                      ),
                    )
                  : CupertinoActivityIndicator.partiallyRevealed(
                      radius: 9.r,
                      progress: progress,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.72,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
