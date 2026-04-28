import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class ReferralStatsGrid extends StatelessWidget {
  const ReferralStatsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.people,
                  iconColor: const Color(0xFF7434FF),
                  title: 'Total Referrals',
                  value: '12',
                  valueColor: const Color(0xFF0F1D40),
                ),
              ),
              hSpace(12),
              Expanded(
                child: _StatCard(
                  icon: Icons.trending_up,
                  iconColor: const Color(0xFF4CAF50),
                  title: 'Active',
                  value: '8',
                  valueColor: const Color(0xFF0F1D40),
                ),
              ),
            ],
          ),
          vSpace(12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.people,
                  iconColor: const Color(0xFF7434FF),
                  title: 'Total Earned',
                  value: '₦45,000',
                  valueColor: const Color(0xFF4CAF50),
                ),
              ),
              hSpace(12),
              Expanded(
                child: _StatCard(
                  icon: Icons.trending_up,
                  iconColor: const Color(0xFF4CAF50),
                  title: 'Pending Rewards',
                  value: '₦15,000',
                  valueColor: const Color(0xFFFF9800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 24.sp,
          ),
          vSpace(12),
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              color: Colors.grey.shade600,
            ),
          ),
          vSpace(8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}





