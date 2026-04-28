import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class CommunityInfoCard extends StatelessWidget {
  const CommunityInfoCard({
    super.key,
    required this.communityName,
    required this.memberCount,
    required this.role,
    this.logoUrl,
  });

  final String communityName;
  final int memberCount;
  final String role;
  final String? logoUrl;

  bool get _hasLogo {
    final u = logoUrl?.trim();
    if (u == null || u.isEmpty) return false;
    return u.startsWith('http://') || u.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF7434FF),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Container(
              width: 56.w,
              height: 56.w,
              color: Colors.white.withValues(alpha: 0.2),
              child: _hasLogo
                  ? Image.network(
                      logoUrl!.trim(),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.people,
                        color: Colors.white,
                        size: 30.sp,
                      ),
                    )
                  : Icon(
                      Icons.people,
                      color: Colors.white,
                      size: 30.sp,
                    ),
            ),
          ),
          hSpace(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  communityName,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                vSpace(4),
                Text(
                  '$memberCount members • $role',
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: Colors.white.withValues(alpha: 0.9),
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
