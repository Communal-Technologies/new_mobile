import 'package:flutter/material.dart';

/// Circle avatar that renders a network image when [url] is a valid
/// HTTP(S) URL and falls back to [fallbackAsset] when:
///
/// - the URL is null/empty/non-HTTP, or
/// - the network image fails to decode (expired secure-upload
///   signatures returning HTML error bodies, 404s, network drops, …).
///
/// Without the explicit error fallback the underlying [CircleAvatar]
/// surfaces a `_Exception("Invalid image data")` to the image
/// resource service and pollutes the console (and, depending on
/// surface, leaves a permanently broken visual).
class MemberAvatar extends StatefulWidget {
  const MemberAvatar({
    super.key,
    required this.url,
    required this.radius,
    this.fallbackAsset = 'assets/images/demo_user.png',
    this.backgroundColor,
  });

  final String? url;
  final double radius;
  final String fallbackAsset;
  final Color? backgroundColor;

  @override
  State<MemberAvatar> createState() => _MemberAvatarState();
}

class _MemberAvatarState extends State<MemberAvatar> {
  bool _networkFailed = false;

  bool get _isUsableUrl {
    final u = widget.url?.trim() ?? '';
    if (u.isEmpty) return false;
    return u.startsWith('http://') || u.startsWith('https://');
  }

  @override
  void didUpdateWidget(covariant MemberAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _networkFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = AssetImage(widget.fallbackAsset);
    final useNetwork = _isUsableUrl && !_networkFailed;
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor:
          widget.backgroundColor ?? Theme.of(context).dividerColor,
      backgroundImage:
          useNetwork ? NetworkImage(widget.url!.trim()) : fallback,
      onBackgroundImageError: useNetwork
          ? (error, stackTrace) {
              // Debug-only diagnostic: surfaces the URL + first 80
              // chars of the error so format failures (HEIC/AVIF the
              // Android decoder rejects with "unimplemented"), 4xx
              // responses, and HTML-error-bodies-from-presigned-URLs
              // can be told apart on logcat without instrumenting
              // each call site. Stripped in release via assert().
              assert(() {
                final url = widget.url ?? '';
                final masked =
                    url.length > 120 ? '${url.substring(0, 120)}…' : url;
                final errStr = error.toString();
                final clipped = errStr.length > 80
                    ? '${errStr.substring(0, 80)}…'
                    : errStr;
                debugPrint(
                    'MemberAvatar: decode failed url=$masked err=$clipped');
                return true;
              }());
              if (!mounted) return;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || _networkFailed) return;
                setState(() => _networkFailed = true);
              });
            }
          : null,
    );
  }
}
