import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key});

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
                onPressed: () {
                  // TODO: Navigate to report scam
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report Scam')),
                  );
                },
                icon: Icon(
                  Icons.warning,
                  color: Colors.red,
                  size: 20.sp,
                ),
                label: Text(
                  'Report Scam',
                  style: TextStyle(
                    fontSize: 15.sp,
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
                onPressed: () {
                  // TODO: Open live chat
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening Live Chat...')),
                  );
                },
                icon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: const BoxDecoration(
                        color: Colors.green,
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
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'AVG. Response time: 1 min',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.white.withOpacity(0.9),
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

