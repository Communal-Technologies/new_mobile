import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A bank's or biller's mark, with the initials monogram as the real fallback.
///
/// The API omits `logo_url` for anything we hold no artwork for — most of the 618
/// banks Anchor lists — so the monogram is not an error state, it is the normal
/// rendering for a long tail of microfinance banks. It is drawn from the name the
/// row already carries, so it costs no request and works offline.
///
/// The tile is white in both themes. Bank artwork is a transparent PNG and a good
/// half of it is dark-on-transparent — a navy "N", a black square, a dark green
/// wordmark — which disappears entirely on a dark surface. Every banking app puts
/// these on white for the same reason.
///
/// [BoxFit.contain] and not the [CircleAvatar.backgroundImage] the rest of the app
/// uses for member photos: that is `cover`, which crops a wide wordmark's ends off
/// and turns a legible mark into an unrecognisable middle.
class BrandLogo extends StatefulWidget {
  const BrandLogo({
    super.key,
    required this.name,
    required this.logoUrl,
    this.size = 44,
  });

  /// Used for the monogram, so it must be the display name and not a slug.
  final String name;

  /// `logo_url` from the API. Null, empty or non-HTTP draws the monogram.
  final String? logoUrl;

  /// Diameter in logical pixels, before `.r`/`.sp` scaling.
  final double size;

  @override
  State<BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<BrandLogo> {
  bool _failed = false;

  bool get _hasUrl {
    final u = widget.logoUrl?.trim() ?? '';
    return u.startsWith('http://') || u.startsWith('https://');
  }

  @override
  void didUpdateWidget(covariant BrandLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logoUrl != widget.logoUrl) {
      _failed = false;
    }
  }

  /// Two letters where the name has two meaningful words, one otherwise.
  ///
  /// "Bank", "PLC" and the rest are dropped because they are what every row has
  /// in common: "Access Bank" and "Alat Bank" both reading "AB" is worse than no
  /// mark at all, and a picker of 618 rows is where that collision shows up.
  String _initials() {
    const noise = {
      'bank',
      'banks',
      'plc',
      'ltd',
      'limited',
      'nigeria',
      'nigerian',
      'ng',
      'mfb',
      'microfinance',
      'psb',
      'and',
      'the',
      'company',
      'services',
      'service',
      'distribution',
      'electricity',
      'electric',
      'prepaid',
      'postpaid',
      'subscription',
      'payments',
      'payment',
    };
    final words = widget.name
        .replaceAll(RegExp(r'[^A-Za-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    final meaty = words
        .where((w) => !noise.contains(w.toLowerCase()))
        .toList();
    final parts = meaty.isEmpty ? words : meaty;
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts.first;
      return (w.length >= 2 ? w.substring(0, 2) : w).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.size.r;
    final primary = Theme.of(context).primaryColor;

    final monogram = Center(
      child: Text(
        _initials(),
        maxLines: 1,
        style: TextStyle(
          fontSize: (widget.size * 0.36).sp,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: primary,
        ),
      ),
    );

    Widget child = monogram;
    if (_hasUrl && !_failed) {
      child = Padding(
        // The artwork is already centred in its own transparent square; this is
        // the breathing room a circular tile needs so a square mark's corners do
        // not touch the edge.
        padding: EdgeInsets.all(widget.size * 0.14),
        child: Image.network(
          widget.logoUrl!.trim(),
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          // The monogram stands in while the image loads, so a slow network shows
          // a correct mark rather than an empty circle that then pops.
          loadingBuilder: (context, widget_, progress) =>
              progress == null ? widget_ : monogram,
          errorBuilder: (context, error, stack) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _failed) return;
              setState(() => _failed = true);
            });
            return monogram;
          },
        ),
      );
    }

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        color: _hasUrl && !_failed ? Colors.white : primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
