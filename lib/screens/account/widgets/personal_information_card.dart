import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class PersonalInformationCard extends StatelessWidget {
  const PersonalInformationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline,
                color: const Color(0xFF7434FF),
                size: 20.sp,
              ),
              hSpace(8),
              Text(
                'Personal Information',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F1D40),
                ),
              ),
            ],
          ),
          vSpace(20),
          _InfoRow(label: 'First Name', value: 'Pado'),
          vSpace(16),
          _InfoRow(label: 'Last Name', value: 'Lebari'),
          vSpace(16),
          _InfoRowWithIcon(
            icon: Icons.email_outlined,
            label: 'Email Address',
            value: 'pado.lebari@example.com',
          ),
          vSpace(16),
          _InfoRowWithIcon(
            icon: Icons.phone_outlined,
            label: 'Phone Number',
            value: '+234 801 234 5678',
          ),
          vSpace(16),
          _InfoRowWithIcon(
            icon: Icons.calendar_today_outlined,
            label: 'Date of Birth',
            value: '15 May 1990',
          ),
          vSpace(16),
          _InfoRowWithIcon(
            icon: Icons.work_outline,
            label: 'Occupation',
            value: 'Software Engineer',
          ),
          vSpace(20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.pushNamed('edit-profile');
              },
              icon: Icon(Icons.edit, size: 18.sp),
              label: Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: const Color(0xFF7434FF)),
                foregroundColor: const Color(0xFF7434FF),
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15.sp,
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F1D40),
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRowWithIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRowWithIcon({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18.sp,
              color: Colors.grey.shade600,
            ),
            hSpace(8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15.sp,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0F1D40),
            ),
          ),
        ),
      ],
    );
  }
}

