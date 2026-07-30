import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/community/data/sample_communities.dart';

class CommunityTile extends StatelessWidget {
  const CommunityTile({
    super.key,
    required this.community,
    required this.isActive,
    required this.onSelect,
  });

  final Community community;
  final bool isActive;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isActive ? const Color(0xFF7434FF) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAvatar(
                community.initials,
                background: const LinearGradient(
                  colors: [Color(0xFF4DD5FF), Color(0xFF7434FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
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
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isVerified(community)) ...[
                          hSpace(6),
                          Icon(
                            Icons.verified,
                            size: 18.sp,
                            color: const Color(0xFF4CAF50),
                          ),
                        ],
                      ],
                    ),
                    vSpace(4),
                    Row(
                      children: [
                        Icon(
                          Icons.people_alt,
                          size: 14.sp,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        hSpace(4),
                        Text(
                          community.membersLabel,
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                        hSpace(12),
                        Icon(
                          Icons.access_time,
                          size: 14.sp,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        hSpace(4),
                        Text(
                          'Since ${community.sinceLabel}',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Active-membership check sits at the *card's* top-right
              // (sibling of the avatar/details column) so it lines up
              // with the avatar regardless of how the name wraps.
              if (isActive)
                Padding(
                  padding: EdgeInsets.only(left: 8.w, top: 2.h),
                  child: Icon(
                    Icons.check_circle,
                    color: const Color(0xFF7434FF),
                    size: 22.sp,
                  ),
                ),
            ],
          ),
          vSpace(10),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFFE9F2FF),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              community.membershipLabel,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5B5CE2),
              ),
            ),
          ),
          vSpace(12),
          if (!isActive)
            OutlinedButton(
              onPressed: onSelect,
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 48.h),
                side: const BorderSide(color: Color(0xFF7434FF), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                'Switch to this Community',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF7434FF),
                ),
              ),
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
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
