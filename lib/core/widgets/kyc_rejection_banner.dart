import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Shown on a KYC resubmission screen (bank or proof) when the member is here to
/// re-do a submission Anchor turned down. It carries the provider's reason so the
/// member corrects what was wrong rather than resubmitting the same thing blind.
/// Renders nothing when there is no message to show.
class KycRejectionBanner extends StatelessWidget {
  const KycRejectionBanner({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final msg = message?.trim() ?? '';
    if (msg.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.error;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: fg.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: fg, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your last submission was not approved',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  msg,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: scheme.onSurface.withValues(alpha: 0.85),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Correct the details below and submit again.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
