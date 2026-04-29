import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/repositories/community_repository.dart';
import 'package:communal_mobile/injection.dart';
import 'package:communal_mobile/screens/community/data/sample_community_details.dart';
import 'package:communal_mobile/screens/community/data/sample_community_locations.dart';

class CommunityApplicationStatusScreen extends StatefulWidget {
  const CommunityApplicationStatusScreen({super.key, required this.detail});

  final CommunityDetail detail;

  @override
  State<CommunityApplicationStatusScreen> createState() =>
      _CommunityApplicationStatusScreenState();
}

class _CommunityApplicationStatusScreenState
    extends State<CommunityApplicationStatusScreen> {
  late Future<CommunityJoinRequest?> _request;

  @override
  void initState() {
    super.initState();
    _request = _loadLatest();
  }

  Future<CommunityJoinRequest?> _loadLatest() async {
    final all = await getIt<CommunityRepository>().fetchMyJoinRequests();
    final cooperativeId = widget.detail.location.id;
    final matching = all.where((r) => r.cooperativeId == cooperativeId).toList();
    if (matching.isEmpty) return null;
    matching.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return matching.first;
  }

  Future<void> _refresh() async {
    setState(() {
      _request = _loadLatest();
    });
    await _request;
  }

  Future<void> _cancel(CommunityJoinRequest request) async {
    try {
      await getIt<CommunityRepository>().cancelJoinRequest(request.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request cancelled.')),
      );
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = widget.detail.location;

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
      body: FutureBuilder<CommunityJoinRequest?>(
        future: _request,
        builder: (context, snapshot) {
          final request = snapshot.data;
          final loading = snapshot.connectionState == ConnectionState.waiting;
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 12.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderCard(location),
                        vSpace(16),
                        if (loading)
                          const Center(child: CircularProgressIndicator())
                        else
                          _buildBanner(snapshot, request),
                        vSpace(16),
                        _buildStatsCard(),
                        vSpace(16),
                        _buildAboutSection(),
                        vSpace(32),
                      ],
                    ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: _buildFooter(loading, request),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBanner(AsyncSnapshot snapshot, CommunityJoinRequest? request) {
    if (snapshot.hasError) {
      return _Banner(
        background: const Color(0xFFFDECEA),
        border: const Color(0xFFFAC0BA),
        icon: Icons.error_outline,
        iconColor: const Color(0xFFB42318),
        textColor: const Color(0xFFB42318),
        title: 'Could not load status',
        body: snapshot.error.toString().replaceFirst('Exception: ', ''),
      );
    }
    if (request == null) {
      return _Banner(
        background: const Color(0xFFEFF1FF),
        border: const Color(0xFFCBD0FF),
        icon: Icons.help_outline,
        iconColor: const Color(0xFF3F51B5),
        textColor: const Color(0xFF3F51B5),
        title: 'No application yet',
        body: 'You haven\'t submitted a request for this cooperative.',
      );
    }
    switch (request.status) {
      case JoinRequestStatus.pending:
        return _Banner(
          background: const Color(0xFFFFF4E9),
          border: const Color(0xFFFFD2B0),
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFEE7B00),
          textColor: const Color(0xFF9A4F00),
          title: 'Application Pending',
          body: 'Your request to join is under review by the admin.',
        );
      case JoinRequestStatus.approved:
        return _Banner(
          background: const Color(0xFFE7F7EE),
          border: const Color(0xFFB6E2C7),
          icon: Icons.check_circle_outline,
          iconColor: const Color(0xFF1F8B4C),
          textColor: const Color(0xFF1F8B4C),
          title: 'Application Approved',
          body: 'You are now a member of this cooperative.',
        );
      case JoinRequestStatus.declined:
        return _Banner(
          background: const Color(0xFFFDECEA),
          border: const Color(0xFFFAC0BA),
          icon: Icons.cancel_outlined,
          iconColor: const Color(0xFFB42318),
          textColor: const Color(0xFFB42318),
          title: 'Application Declined',
          body: request.declineReason?.trim().isNotEmpty == true
              ? request.declineReason!
              : 'The cooperative admin declined your request.',
        );
      case JoinRequestStatus.cancelled:
        return _Banner(
          background: const Color(0xFFF1F0F5),
          border: const Color(0xFFD9D6E0),
          icon: Icons.do_disturb_alt_outlined,
          iconColor: const Color(0xFF6F6E7B),
          textColor: const Color(0xFF6F6E7B),
          title: 'Application Cancelled',
          body: 'You cancelled this request.',
        );
      case JoinRequestStatus.unknown:
        return _Banner(
          background: const Color(0xFFF1F0F5),
          border: const Color(0xFFD9D6E0),
          icon: Icons.info_outline,
          iconColor: const Color(0xFF6F6E7B),
          textColor: const Color(0xFF6F6E7B),
          title: 'Status unavailable',
          body: 'Try refreshing in a moment.',
        );
    }
  }

  Widget _buildHeaderCard(CommunityLocation location) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 32.r,
            backgroundColor: const Color(0xFFE5E0FF),
            child: const Icon(
              Icons.apartment_rounded,
              color: Color(0xFF7434FF),
              size: 28,
            ),
          ),
          vSpace(12),
          Text(
            location.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(6),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF1FF),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Text(
              widget.detail.categoryLabel,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF5B5CE2),
              ),
            ),
          ),
          vSpace(12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMeta(Icons.people, '${location.members} members'),
              hSpace(16),
              _buildMeta(Icons.place_outlined, location.distanceLabel),
              hSpace(16),
              _buildMeta(
                Icons.star,
                '${location.rating.toStringAsFixed(1)} (89)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final stats = widget.detail.stats;
    final items = [
      (stats.totalLoans, 'Total Loans Given'),
      (stats.totalSavings, 'Total Savings'),
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

          Color valueColor;
          switch (index) {
            case 0:
            case 2:
              valueColor = const Color(0xFF7434FF);
              break;
            case 1:
            case 5:
              valueColor = const Color(0xFF27AE60);
              break;
            case 3:
              valueColor = const Color(0xFF2F80ED);
              break;
            case 4:
              valueColor = const Color(0xFFE67E22);
              break;
            default:
              valueColor = const Color(0xFF0F1D40);
          }
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
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
                vSpace(4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
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
            'About',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          vSpace(12),
          Text(
            widget.detail.about,
            style: TextStyle(fontSize: 13.5.sp, color: Colors.grey.shade700),
          ),
          vSpace(16),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.h,
            children: [
              _buildMetaChip(Icons.calendar_today, widget.detail.foundedDate),
              _buildMetaChip(Icons.money, widget.detail.contributionRange),
              _buildMetaChip(Icons.location_on, 'Lagos, Nigeria'),
              _buildMetaChip(
                Icons.verified,
                widget.detail.isVerified ? 'Verified Community' : 'Unverified',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMeta(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: Colors.grey.shade600),
        hSpace(4),
        Text(
          label,
          style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade600),
        ),
      ],
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
            style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool loading, CommunityJoinRequest? request) {
    if (loading || request == null) {
      return const SizedBox.shrink();
    }
    if (request.status != JoinRequestStatus.pending) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () => _cancel(request),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, 52.h),
            side: const BorderSide(color: Color(0xFFE74C3C)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          ),
          child: Text(
            'Cancel Request',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFE74C3C),
            ),
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.background,
    required this.border,
    required this.icon,
    required this.iconColor,
    required this.textColor,
    required this.title,
    required this.body,
  });

  final Color background;
  final Color border;
  final IconData icon;
  final Color iconColor;
  final Color textColor;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                vSpace(4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: textColor,
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
