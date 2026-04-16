import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class HomeHeader extends StatelessWidget {
  final GlobalKey<ScaffoldState> scaffoldKey;
  final ThemeData theme;

  const HomeHeader({
    super.key,
    required this.scaffoldKey,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(right: 16.w, top: 12.h, bottom: 12.h, left: 0),
      color: Colors.white,
      child: Row(
        children: [
          // Purple button with switch arrow - TOUCHES LEFT EDGE - Opens Drawer
          InkWell(
            onTap: () {
              scaffoldKey.currentState?.openDrawer();
            },
            child: Container(
              width: 40.w,
              height: 40.w,
              margin: EdgeInsets.only(right: 8.w),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(20.r),
                  bottomRight: Radius.circular(20.r),
                ),
              ),
              child: Center(
                child: Icon(Icons.swap_horiz, color: Colors.white, size: 22.sp),
              ),
            ),
          ),
          // Logo card with white background - NARROWER
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6.r),
              border: Border.all(color: Colors.grey.shade200, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Exxon',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                      TextSpan(
                        text: 'Mobil',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Bullion Crib',
                  style: TextStyle(
                    fontSize: 9.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
          hSpace(12),
          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Pado Lebari',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    hSpace(8),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        'Member',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                vSpace(4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey.shade600,
                    ),
                    children: [
                      const TextSpan(text: 'Lets save that '),
                      TextSpan(
                        text: '1 million',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const TextSpan(text: ' this month'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Notification - LARGER
          IconButton(
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              Icons.notifications_outlined,
              color: Colors.grey.shade700,
              size: 28.sp,
            ),
          ),
          hSpace(12),
          // Profile picture - LARGER
          InkWell(
            onTap: () {
              context.pushNamed('my-profile');
            },
            borderRadius: BorderRadius.circular(22.w),
            child: CircleAvatar(
              radius: 22.w,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: const AssetImage('assets/images/demo_user.png'),
            ),
          ),
        ],
      ),
    );
  }
}

