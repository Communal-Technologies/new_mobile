import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/community/data/sample_community_details.dart';
import 'package:communal_mobile/screens/community/data/sample_community_locations.dart';

class CommunityApplicationStatusScreen extends StatelessWidget {
  const CommunityApplicationStatusScreen({super.key, required this.detail});

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
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {},
          ),
        ],
      ),
      bottomNavigationBar: _buildPendingFooter(),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(location),
            vSpace(16),
            _buildPendingBanner(),
            vSpace(16),
            _buildStatsCard(),
            vSpace(16),
            _buildAboutSection(),
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 64.w,
            width: 64.w,
            child: Image.asset(
              'assets/icons/community_placeholder.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => CircleAvatar(
                radius: 32.r,
                backgroundColor: const Color(0xFFE5E0FF),
                child: const Icon(Icons.apartment_rounded,
                    color: Color(0xFF7434FF), size: 28),
              ),
            ),
          ),
          vSpace(12),
          Text(
            location.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
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
              detail.categoryLabel,
              style: TextStyle(
                fontSize: 12.sp,
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
              _buildMeta(Icons.place_outlined, '${location.distanceKm} km'),
              hSpace(16),
              _buildMeta(Icons.star, '${location.rating} (${location.members})'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPendingBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E9),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFFFD2B0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFEE7B00)),
          hSpace(12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Application Pending',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF9A4F00),
                  ),
                ),
                vSpace(4),
                Text(
                  'Your request to join is under review by the admin.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: const Color(0xFF9A4F00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final stats = detail.stats;
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
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
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
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(12),
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

  Widget _buildMeta(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16.sp, color: Colors.grey.shade600),
        hSpace(4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.grey.shade600,
          ),
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
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingFooter() {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: const Color(0xFFF4EFE7),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: const Icon(Icons.schedule, color: Color(0xFF9A4F00)),
            ),
            hSpace(12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Application Pending',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F1D40),
                    ),
                  ),
                  vSpace(4),
                  Text(
                    'We’ll notify you once the admin reviews your request.',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

