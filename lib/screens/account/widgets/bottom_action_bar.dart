import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/support_models.dart';

/// The two things a member on the help screen most often wants: to report
/// something urgent, or to talk to us.
///
/// Both open a support conversation. "Report Scam" is not a separate flow — it
/// is a ticket in the security category, which the assistant is required to hand
/// straight to a person rather than answer, and which arrives in the queue with
/// whatever the member typed.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key, this.operatorsOnline = false});

  /// Whether an operator is at the desk right now, from the support config. The
  /// dot and the subtitle used to claim a one-minute response unconditionally.
  final bool operatorsOnline;

  void _open(
    BuildContext context,
    String category,
    String title, {
    String? openingMessage,
  }) {
    context.pushNamed(
      'support-chat',
      extra: <String, dynamic>{
        'category': category,
        'categoryTitle': title,
        if (openingMessage != null) 'openingMessage': openingMessage,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).dividerColor,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _open(
                  context,
                  SupportCategory.security,
                  'Report Scam',
                  openingMessage: 'I want to report a scam. ',
                ),
                icon: Icon(
                  Icons.warning,
                  color: Colors.red,
                  size: 20.sp,
                ),
                label: Text(
                  'Report Scam',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red, width: 1.5),
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
            ),
            hSpace(12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _open(context, SupportCategory.general, 'Live Chat'),
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        color: operatorsOnline ? Colors.green : Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    hSpace(6),
                    Icon(
                      Icons.chat_bubble,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                  ],
                ),
                label: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Live Chat',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      operatorsOnline
                          ? 'Our team is online now'
                          : 'Assistant replies right away',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7434FF),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
