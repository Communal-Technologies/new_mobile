import 'package:flutter/material.dart';

/// Circle avatar that renders a network image when [url] is a valid
/// HTTP(S) URL and falls back to showing the user's initials (derived from
/// [name]) when:
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
    this.name,
    this.backgroundColor,
  });

  final String? url;
  final double radius;
  /// Display name used to derive initials when there is no avatar image.
  final String? name;
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

  String _initials() {
    final raw = (widget.name ?? '').trim();
    if (raw.isEmpty) return '?';
    final parts = raw.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final useNetwork = _isUsableUrl && !_networkFailed;
    final bg = widget.backgroundColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.15);

    if (useNetwork) {
      return CircleAvatar(
        radius: widget.radius,
        backgroundColor: bg,
        backgroundImage: NetworkImage(widget.url!.trim()),
        onBackgroundImageError: (error, stackTrace) {
          assert(() {
            final url = widget.url ?? '';
            final masked = url.length > 120 ? '${url.substring(0, 120)}…' : url;
            final errStr = error.toString();
            final clipped = errStr.length > 80 ? '${errStr.substring(0, 80)}…' : errStr;
            debugPrint('MemberAvatar: decode failed url=$masked err=$clipped');
            return true;
          }());
          if (!mounted) return;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _networkFailed) return;
            setState(() => _networkFailed = true);
          });
        },
      );
    }

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: bg,
      child: Text(
        _initials(),
        style: TextStyle(
          fontSize: widget.radius * 0.72,
          fontWeight: FontWeight.w700,
          color: widget.backgroundColor != null
              ? Colors.white
              : Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}
