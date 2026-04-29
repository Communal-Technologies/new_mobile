import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/community/data/sample_communities.dart';

class FeaturedCommunityCard extends StatelessWidget {
  const FeaturedCommunityCard({
    super.key,
    required this.community,
    this.onOpenChat,
    this.onViewCommunity,
  });

  final Community community;
  final VoidCallback? onOpenChat;
  final VoidCallback? onViewCommunity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7434FF), Color(0xFF8A49FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(
                community.initials,
                size: 54.w,
                backgroundColor: Colors.white24,
              ),
              hSpace(12),
              Expanded(
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            community.name,
                            style: TextStyle(
                              fontSize: 19.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isVerified(community)) ...[
                          hSpace(6),
                          Icon(
                            Icons.verified,
                            size: 18.sp,
                            color: Colors.white,
                          ),
                        ],
                      ],
                    ),
                    vSpace(4),
                    Text(
                      '${community.role} · ${community.membersLabel}',
                      style: TextStyle(fontSize: 15.sp, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          vSpace(18),
          Row(
            children: [
              // TODO(communal-mobile): re-enable Open Chat once the
              // in-app cooperative chat is built. Hidden for now so
              // a non-functional CTA doesn't ship — the View button
              // expands to fill the row in the meantime.
              // Expanded(
              //   child: ElevatedButton(
              //     onPressed: onOpenChat,
              //     style: ElevatedButton.styleFrom(
              //       backgroundColor: const Color(0xFF9C6BFF),
              //       minimumSize: Size(double.infinity, 46.h),
              //       elevation: 0,
              //       shape: RoundedRectangleBorder(
              //         borderRadius: BorderRadius.circular(12.r),
              //       ),
              //     ),
              //     child: Text(
              //       'Open Chat',
              //       style: TextStyle(
              //         fontSize: 15.sp,
              //         fontWeight: FontWeight.w600,
              //         color: Colors.white,
              //       ),
              //     ),
              //   ),
              // ),
              // hSpace(12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onViewCommunity,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF31E3FF),
                    minimumSize: Size(double.infinity, 46.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    'View Cooperative',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F1D40),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool _isVerified(Community community) {
    try {
      return community.isVerified;
    } catch (e) {
      return false;
    }
  }

  Widget _buildAvatar(
    String initials, {
    double size = 48,
    Gradient? background,
    Color? backgroundColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: background,
        color: background == null
            ? (backgroundColor ?? const Color(0xFF7434FF))
            : null,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            fontSize: 17.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
