import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class ReferralHistorySection extends StatelessWidget {
  const ReferralHistorySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Referral History',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F1D40),
            ),
          ),
          vSpace(16),
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              children: [
                _ReferralHistoryItem(
                  name: 'John Adeleke',
                  date: 'Jan 5, 2025',
                  amount: '₦5,000',
                  status: 'Completed',
                  statusColor: const Color(0xFF4CAF50),
                ),
                vSpace(16),
                _ReferralHistoryItem(
                  name: 'Sarah Okonkwo',
                  date: 'Jan 3, 2025',
                  amount: '₦5,000',
                  status: 'Completed',
                  statusColor: const Color(0xFF4CAF50),
                ),
                vSpace(16),
                _ReferralHistoryItem(
                  name: 'David Musa',
                  date: 'Jan 1, 2025',
                  amount: '₦5,000',
                  status: 'Active',
                  statusColor: const Color(0xFFE3F2FD),
                ),
                vSpace(16),
                _ReferralHistoryItem(
                  name: 'Grace Nwankwo',
                  date: 'Dec 28, 2024',
                  amount: '₦5,000',
                  status: 'Pending',
                  statusColor: const Color(0xFFFFF3E0),
                ),
                vSpace(16),
                _ReferralHistoryItem(
                  name: 'Michael Bello',
                  date: 'Dec 25, 2024',
                  amount: '₦5,000',
                  status: 'Completed',
                  statusColor: const Color(0xFF4CAF50),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReferralHistoryItem extends StatelessWidget {
  final String name;
  final String date;
  final String amount;
  final String status;
  final Color statusColor;

  const _ReferralHistoryItem({
    required this.name,
    required this.date,
    required this.amount,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    Color statusTextColor;
    if (status == 'Completed') {
      statusTextColor = const Color(0xFF4CAF50);
    } else if (status == 'Active') {
      statusTextColor = const Color(0xFF2196F3);
    } else {
      statusTextColor = const Color(0xFFFF9800);
    }

    return Row(
      children: [
        Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7434FF), Color(0xFF1976D2)],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_outline,
            color: Colors.white,
            size: 20.sp,
          ),
        ),
        hSpace(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F1D40),
                ),
              ),
              vSpace(2),
              Text(
                date,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F1D40),
              ),
            ),
            vSpace(4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: statusTextColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}





