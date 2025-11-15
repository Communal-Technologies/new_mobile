import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/community/data/sample_community_details.dart';
import 'package:communal_mobile/screens/community/data/sample_community_locations.dart';

class CommunityDetailScreen extends StatelessWidget {
  const CommunityDetailScreen({super.key, required this.detail});

  final CommunityDetail detail;

  @override
  Widget build(BuildContext context) {
    final location = detail.location;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F6FA),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Community Details',
          style: TextStyle(color: Color(0xFF0F1D40)),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(location),
            vSpace(16),
            _buildStatsCard(),
            vSpace(16),
            _buildAboutSection(),
            vSpace(16),
            _buildCoordinatorSection(),
            vSpace(16),
            _buildMeetingSection(),
            vSpace(16),
            _buildChecklistSection(
              title: 'Membership Requirements',
              items: detail.membershipRequirements,
            ),
            vSpace(16),
            _buildBulletSection(
              title: 'Member Benefits',
              items: detail.benefits,
            ),
            vSpace(16),
            _buildRecentActivities(),
            vSpace(32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(CommunityLocation location) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8ECFF),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: const Icon(
                  Icons.apartment_rounded,
                  color: Color(0xFF7434FF),
                  size: 32,
                ),
              ),
              hSpace(16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F1D40),
                      ),
                    ),
                    vSpace(6),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF1FF),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: Text(
                        detail.categoryLabel,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5B5CE2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.favorite_border),
                onPressed: () {},
              ),
            ],
          ),
          vSpace(16),
          Row(
            children: [
              _buildHeaderMeta(
                icon: Icons.people,
                label: '${location.members} members',
              ),
              _buildHeaderMeta(
                icon: Icons.place_outlined,
                label: '${location.distanceKm} km',
              ),
              _buildHeaderMeta(
                icon: Icons.star,
                label: location.rating.toStringAsFixed(1),
              ),
            ],
          ),
          vSpace(16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7434FF),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Text(
                'Join Community',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMeta({required IconData icon, required String label}) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: Colors.grey.shade600),
          hSpace(6),
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final stats = detail.stats;
    final items = [
      ('${stats.totalLoans}', 'Total Loans Given'),
      ('${stats.totalSavings}', 'Total Savings'),
      (stats.monthlyContribution, 'Contribution'),
      (stats.activeLoans, 'Active Loans'),
      (stats.defaultRate, 'Default Rate'),
      (stats.loanInterestRate, 'Loan Interest Rate'),
    ];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 2.8,
          mainAxisSpacing: 12.h,
          crossAxisSpacing: 12.w,
        ),
        itemBuilder: (context, index) {
          final (value, label) = items[index];
          return Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8FF),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F1D40),
                  ),
                ),
                vSpace(4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAboutSection() {
    return _SectionCard(
      title: 'About',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.about,
            style: TextStyle(fontSize: 13.5.sp, color: Colors.grey.shade700),
          ),
          vSpace(16),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            children: [
              _buildMetaChip(Icons.calendar_today, detail.foundedDate),
              _buildMetaChip(Icons.money, detail.contributionRange),
              _buildMetaChip(Icons.location_on, 'Lagos, Nigeria'),
              _buildMetaChip(
                Icons.verified,
                detail.isVerified ? 'Verified Community' : 'Unverified',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F3F9),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: const Color(0xFF5B5CE2)),
          hSpace(6),
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordinatorSection() {
    return _SectionCard(
      title: 'Community Coordinator',
      child: Row(
        children: [
          CircleAvatar(
            radius: 28.r,
            backgroundColor: const Color(0xFFE0D8FF),
            child: Text(
              detail.coordinatorName.isNotEmpty
                  ? detail.coordinatorName
                        .split(' ')
                        .map((word) => word[0])
                        .take(2)
                        .join()
                  : 'CC',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF4328B8),
              ),
            ),
          ),
          hSpace(16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  detail.coordinatorName,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F1D40),
                  ),
                ),
                vSpace(4),
                Text(
                  detail.coordinatorRole,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.call_outlined, color: Color(0xFF7434FF)),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.chat_bubble_outline,
              color: Color(0xFF7434FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingSection() {
    return _SectionCard(
      title: 'Meeting Schedule',
      child: Row(
        children: [
          Expanded(
            child: Text(
              detail.meetingSchedule,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0F1D40),
              ),
            ),
          ),
          Text(
            detail.meetingTime,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7434FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistSection({
    required String title,
    required List<String> items,
  }) {
    return _SectionCard(
      title: title,
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF4CAF50),
                      size: 20,
                    ),
                    hSpace(12),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF0F1D40),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildBulletSection({
    required String title,
    required List<String> items,
  }) {
    return _SectionCard(
      title: title,
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFC107), size: 18),
                    hSpace(12),
                    Expanded(
                      child: Text(
                        item,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF0F1D40),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildRecentActivities() {
    if (detail.recentActivities.isEmpty) {
      return const SizedBox.shrink();
    }

    return _SectionCard(
      title: 'Recent Activities',
      child: Column(
        children: detail.recentActivities
            .map(
              (activity) => Container(
                margin: EdgeInsets.only(bottom: 12.h),
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8FF),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _activityIcon(activity.icon),
                    hSpace(12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.title,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF0F1D40),
                            ),
                          ),
                          vSpace(4),
                          Text(
                            activity.subtitle,
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      activity.daysAgo,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _activityIcon(String type) {
    IconData icon;
    Color color;
    switch (type) {
      case 'loan':
        icon = Icons.attach_money;
        color = const Color(0xFF27AE60);
        break;
      case 'calendar':
        icon = Icons.event;
        color = const Color(0xFF5B5CE2);
        break;
      case 'members':
        icon = Icons.group_add;
        color = const Color(0xFF7434FF);
        break;
      default:
        icon = Icons.info_outline;
        color = const Color(0xFF7434FF);
    }

    return Container(
      width: 40.w,
      height: 40.w,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Icon(icon, color: color, size: 20.sp),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(12),
          child,
        ],
      ),
    );
  }
}
