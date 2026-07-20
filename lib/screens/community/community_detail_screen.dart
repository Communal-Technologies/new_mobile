import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/community_repository.dart';
import 'package:communal_mobile/data/repositories/community_settings_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/community/community_map/join_community_bottom_sheet.dart';
import 'package:communal_mobile/screens/community/data/sample_community_details.dart';
import 'package:communal_mobile/screens/community/data/sample_community_locations.dart';

class CommunityDetailScreen extends StatefulWidget {
  const CommunityDetailScreen({super.key, required this.detail});

  final CommunityDetail detail;

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  // Whether the signed-in user already belongs to this cooperative.
  // Hides the Join CTA in that case — joining a coop you're already
  // in just produces a 409 from the backend.
  bool _isMember = false;

  CommunityDetailStats? _liveStats;

  CommunityDetail get detail => widget.detail;

  @override
  void initState() {
    super.initState();
    _resolveMembership();
    _loadLiveStats();
  }

  Future<void> _loadLiveStats() async {
    try {
      debugPrint('[stats] load for "${detail.location.id}"');
      final m = await getIt<CommunityRepository>()
          .fetchCooperativeStats(detail.location.id);
      debugPrint('[stats] result: $m');
      if (!mounted || m == null) return;
      setState(() {
        _liveStats = CommunityDetailStats(
          totalLoans: m['total_loans'] ?? '',
          totalSavings: m['total_savings'] ?? '',
          monthlyContribution: m['monthly_contribution'] ?? '',
          activeLoans: m['active_loans'] ?? '',
          defaultRate: m['default_rate'] ?? '',
          loanInterestRate: m['loan_interest_rate'] ?? '',
        );
      });
    } catch (e) {
      debugPrint('[stats] error: $e');
    }
  }

  Future<void> _resolveMembership() async {
    try {
      final memberships =
          await getIt<CommunitySettingsRepository>().fetchMemberships();
      if (!mounted) return;
      final coopId = detail.location.id;
      final mine = memberships.any((m) => m.cooperativeId == coopId);
      if (mine != _isMember) setState(() => _isMember = mine);
    } catch (_) {
      // Silent: defaulting to "not a member" so the join CTA is at
      // worst shown when it shouldn't be — backend 409 covers us.
    }
  }

  bool get _hasStats {
    final s = _liveStats ?? detail.stats;
    return [
      s.totalLoans,
      s.totalSavings,
      s.monthlyContribution,
      s.activeLoans,
      s.defaultRate,
      s.loanInterestRate,
    ].any((v) => v.trim().isNotEmpty);
  }

  bool get _hasCoordinator => detail.coordinatorName.trim().isNotEmpty;
  bool get _hasMeeting => detail.meetingSchedule.trim().isNotEmpty;
  bool get _hasRequirements => detail.membershipRequirements.isNotEmpty;
  bool get _hasBenefits => detail.benefits.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final location = detail.location;

    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Community Details',
          style: TextStyle(color: theme.colorScheme.onSurface),
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
            _buildHeaderCard(context, location),
            vSpace(16),
            if (_hasStats) ...[
              _buildStatsCard(),
              vSpace(16),
            ],
            _buildAboutSection(),
            if (_hasCoordinator) ...[
              vSpace(16),
              _buildCoordinatorSection(),
            ],
            if (_hasMeeting) ...[
              vSpace(16),
              _buildMeetingSection(),
            ],
            if (_hasRequirements) ...[
              vSpace(16),
              _buildChecklistSection(
                title: 'Membership Requirements',
                items: detail.membershipRequirements,
              ),
            ],
            if (_hasBenefits) ...[
              vSpace(16),
              _buildBulletSection(
                title: 'Member Benefits',
                items: detail.benefits,
              ),
            ],
            vSpace(16),
            _buildRecentActivities(),
            vSpace(32),
          ],
        ),
      ),
    );
  }

  Future<void> _handleJoin(BuildContext context, CommunityLocation location) async {
    final result = await showModalBottomSheet<CommunityJoinRequest>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JoinCommunityBottomSheet(community: location),
    );
    if (!context.mounted || result == null) return;
    unawaited(context.pushNamed('community-application-status', extra: location));
  }

  Widget _buildHeaderCard(BuildContext context, CommunityLocation location) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
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
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF5B5CE2),
                        ),
                      ),
                    ),
                  ],
                ),
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
                label: location.distanceLabel,
              ),
              _buildHeaderMeta(
                icon: Icons.star,
                label: '${location.rating.toStringAsFixed(1)} (89)',
              ),
            ],
          ),
          vSpace(16),
          Row(
            children: [
              Expanded(
                child: _isMember
                    ? Container(
                        height: 48.h,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F7EE),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(color: const Color(0xFFB6E2C7)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.verified_user,
                              color: Color(0xFF1F8B4C),
                            ),
                            hSpace(8),
                            Text(
                              'You are a member',
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1F8B4C),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () => _handleJoin(context, location),
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
                          style: TextStyle(
                            fontSize: 19.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
              hSpace(12),
              Container(
                width: 48.w,
                height: 48.w,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: const Icon(
                  Icons.favorite_border,
                  color: Color(0xFF9E9EB5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMeta({required IconData icon, required String label}) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
          hSpace(6),
          Text(
            label,
            style: TextStyle(fontSize: 16.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final stats = _liveStats ?? detail.stats;
    final items = [
      ((stats.totalLoans), 'Total Loans Given'),
      ((stats.totalSavings), 'Total Savings'),
      (stats.monthlyContribution, 'Contribution'),
      (stats.activeLoans, 'Active Loans'),
      (stats.defaultRate, 'Default Rate'),
      (stats.loanInterestRate, 'Loan Interest Rate'),
    ];

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        itemCount: items.length,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          // 2.8 was too tight for sp-scaled fonts on smaller devices —
          // the inner Column overflowed by < 1px (the analyzer's "rendering
          // overflow" stripe). Drop to 2.3 so the cells have headroom for
          // the two stacked Text rows + their padding.
          childAspectRatio: 2.3,
          mainAxisSpacing: 12.h,
          crossAxisSpacing: 12.w,
        ),
        itemBuilder: (context, index) {
          final (value, label) = items[index];

          // Match the design-specific accent colors per metric.
          Color valueColor;
          switch (index) {
            case 0:
            case 2:
              valueColor = const Color(0xFF7434FF); // purple
              break;
            case 1:
            case 5:
              valueColor = const Color(0xFF27AE60); // green
              break;
            case 3:
              valueColor = const Color(0xFF2F80ED); // blue
              break;
            case 4:
              valueColor = const Color(0xFFE67E22); // orange
              break;
            default:
              valueColor = Theme.of(context).colorScheme.onSurface;
          }
          return Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
                vSpace(4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
            style: TextStyle(fontSize: 13.5.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
          vSpace(16),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            children: [
              if (detail.foundedDate.trim().isNotEmpty)
                _buildMetaChip(Icons.calendar_today, detail.foundedDate),
              if (detail.contributionRange.trim().isNotEmpty &&
                  detail.contributionRange != '—')
                _buildMetaChip(Icons.money, detail.contributionRange),
              if (detail.location.address.trim().isNotEmpty)
                _buildMetaChip(Icons.location_on, detail.location.address),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16.sp, color: const Color(0xFF5B5CE2)),
          hSpace(6),
          Text(
            label,
            style: TextStyle(fontSize: 16.sp, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
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
                fontSize: 19.sp,
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
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                vSpace(4),
                Text(
                  detail.coordinatorRole,
                  style: TextStyle(
                    fontSize: 17.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                fontSize: 17.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            detail.meetingTime,
            style: TextStyle(
              fontSize: 19.sp,
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
                          fontSize: 17.sp,
                          color: Theme.of(context).colorScheme.onSurface,
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
                          fontSize: 17.sp,
                          color: Theme.of(context).colorScheme.onSurface,
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          vSpace(4),
                          Text(
                            activity.subtitle,
                            style: TextStyle(
                              fontSize: 12.5.sp,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      activity.daysAgo,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(12),
          child,
        ],
      ),
    );
  }
}
