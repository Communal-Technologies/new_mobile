import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/community/data/sample_community_locations.dart';

/// Audit M39: extracted from `community_map_screen.dart`. The card
/// rendered inside the bottom-sheet list — header (avatar + name +
/// rating chip), member-count + distance row, contribution + Join
/// button. Fully stateless; takes the model + two callbacks.
class CommunityCard extends StatelessWidget {
  const CommunityCard({
    super.key,
    required this.community,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
    required this.onJoinPressed,
    this.isMember = false,
  });

  final CommunityLocation community;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;
  final VoidCallback onJoinPressed;

  /// When true, suppress the Join CTA in the footer — the user is
  /// already a member, so showing it would just produce a 409 from
  /// the backend on tap.
  final bool isMember;

  bool get _isVerified {
    try {
      return community.isVerified;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected ? const Color(0xFF7434FF) : Colors.transparent,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommunityCardHeader(
              community: community,
              accentColor: accentColor,
              isVerified: _isVerified,
            ),
            vSpace(12),
            _CommunityCardMeta(community: community),
            vSpace(12),
            _CommunityCardFooter(
              community: community,
              onJoinPressed: onJoinPressed,
              isMember: isMember,
            ),
          ],
        ),
      ),
    );
  }
}

class _CommunityCardHeader extends StatelessWidget {
  const _CommunityCardHeader({
    required this.community,
    required this.accentColor,
    required this.isVerified,
  });

  final CommunityLocation community;
  final Color accentColor;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _CommunityAvatar(accentColor: accentColor),
        hSpace(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Row(
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
                        if (isVerified) ...[
                          hSpace(6),
                          Icon(
                            Icons.verified,
                            size: 18.sp,
                            color: const Color(0xFF4CAF50),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                ],
              ),
              vSpace(4),
              Text(
                community.category,
                style: TextStyle(
                  fontSize: 17.sp,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4D9),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.star,
                color: Color(0xFFFFA426),
                size: 14,
              ),
              hSpace(4),
              Text(
                community.rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFB46A00),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommunityCardMeta extends StatelessWidget {
  const _CommunityCardMeta({required this.community});
  final CommunityLocation community;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.people_alt, size: 16.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        hSpace(4),
        Text(
          community.membersLabel,
          style: TextStyle(fontSize: 16.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        hSpace(12),
        Icon(Icons.place_outlined, size: 16.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        hSpace(4),
        Text(
          community.distanceLabel,
          style: TextStyle(fontSize: 16.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
      ],
    );
  }
}

class _CommunityCardFooter extends StatelessWidget {
  const _CommunityCardFooter({
    required this.community,
    required this.onJoinPressed,
    this.isMember = false,
  });

  final CommunityLocation community;
  final VoidCallback onJoinPressed;
  final bool isMember;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Min. Contribution',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              vSpace(4),
              Text(
                community.minContributionLabel,
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 140.w,
          child: isMember
              ? Container(
                  height: 38.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F7EE),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: const Color(0xFFB6E2C7)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Member',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F8B4C),
                    ),
                  ),
                )
              : ElevatedButton(
                  onPressed: onJoinPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7434FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: Size(double.infinity, 38.h),
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 8.h,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Join Community',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _CommunityAvatar extends StatelessWidget {
  const _CommunityAvatar({required this.accentColor});
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48.w,
      width: 48.w,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Icon(Icons.apartment_rounded, color: accentColor, size: 24.sp),
    );
  }
}
