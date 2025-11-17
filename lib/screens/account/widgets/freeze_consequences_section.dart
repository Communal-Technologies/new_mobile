import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class FreezeConsequencesSection extends StatelessWidget {
  const FreezeConsequencesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What Happens When You Freeze?',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
        ),
        vSpace(20),
        _ConsequenceItem(
          icon: Icons.lock_outline,
          iconColor: const Color(0xFF2196F3),
          title: 'All Transactions Blocked',
          description: 'No deposits, withdrawals, or transfers allowed',
        ),
        vSpace(16),
        _ConsequenceItem(
          icon: Icons.shield_outlined,
          iconColor: const Color(0xFF4CAF50),
          title: 'Data Preserved',
          description: 'All your account data and history remain safe',
        ),
        vSpace(16),
        _ConsequenceItem(
          icon: Icons.email_outlined,
          iconColor: const Color(0xFFFF9800),
          title: 'Notifications Paused',
          description: 'You won\'t receive transaction notifications',
        ),
        vSpace(16),
        _ConsequenceItem(
          icon: Icons.info_outline,
          iconColor: const Color(0xFF7434FF),
          title: 'Cooperative Access Limited',
          description: 'Cannot participate in cooperative related activities',
        ),
      ],
    );
  }
}

class _ConsequenceItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;

  const _ConsequenceItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 22.sp,
          ),
        ),
        hSpace(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0F1D40),
                ),
              ),
              vSpace(4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

