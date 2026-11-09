import 'package:communal_mobile/data/models/announcement.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

/// What the member sees on their first open after signing in: the artwork over
/// a transparent scrim, with an optional button that either opens a section of
/// the app or leaves it.
///
/// The image keeps its own shape — the box takes the aspect ratio the server
/// reports, so tall, square and wide artwork are all shown whole rather than
/// cropped to one frame.
class AnnouncementModal extends StatelessWidget {
  const AnnouncementModal({
    super.key,
    required this.announcement,
    required this.onDismiss,
    required this.onAction,
  });

  final Announcement announcement;
  final VoidCallback onDismiss;
  final ValueChanged<Announcement> onAction;

  static Future<void> show(
    BuildContext context, {
    required Announcement announcement,
    required VoidCallback onDismiss,
    required ValueChanged<Announcement> onAction,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: announcement.dismissible,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => AnnouncementModal(
        announcement: announcement,
        onDismiss: onDismiss,
        onAction: onAction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = announcement.aspectRatio;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (announcement.dismissible)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    onDismiss();
                  },
                  customBorder: const CircleBorder(),
                  child: Container(
                    padding: EdgeInsets.all(6.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close, size: 20.sp, color: Colors.black87),
                  ),
                ),
              ),
            ),
          Flexible(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.r),
              child: ratio == null
                  ? Image.network(
                      announcement.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    )
                  : AspectRatio(
                      aspectRatio: ratio,
                      child: Image.network(
                        announcement.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
            ),
          ),
          if ((announcement.title?.trim().isNotEmpty ?? false) ||
              (announcement.body?.trim().isNotEmpty ?? false))
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(top: 12.h),
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (announcement.title?.trim().isNotEmpty ?? false)
                    Text(
                      announcement.title!,
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700),
                    ),
                  if (announcement.body?.trim().isNotEmpty ?? false) ...[
                    SizedBox(height: 4.h),
                    Text(
                      announcement.body!,
                      style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
                    ),
                  ],
                ],
              ),
            ),
          if (announcement.hasAction)
            Container(
              width: double.infinity,
              margin: EdgeInsets.only(top: 12.h),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  onAction(announcement);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      announcement.actionLabel!,
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                    ),
                    if (announcement.opensOutsideApp) ...[
                      SizedBox(width: 6.w),
                      Icon(Icons.open_in_new, size: 16.sp),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens what an announcement's button points at: a named route inside the app,
/// or a URL away from it.
Future<void> openAnnouncementAction(
  BuildContext context,
  Announcement announcement,
) async {
  final target = announcement.actionTarget?.trim() ?? '';
  if (target.isEmpty) return;

  if (announcement.opensOutsideApp) {
    final uri = Uri.tryParse(target);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return;
  }

  // An in-app target is a route: a path ('/loans') is pushed as one, anything
  // else is treated as a route name so staff can type 'loans'.
  if (target.startsWith('/')) {
    if (context.mounted) await context.push(target);
    return;
  }
  if (context.mounted) await context.pushNamed(target);
}
