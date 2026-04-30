import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/member_profile_details.dart';

class PersonalInformationCard extends StatelessWidget {
  const PersonalInformationCard({
    super.key,
    required this.profile,
    this.onEdited,
  });

  final MemberProfileDetails profile;

  /// Called when the user returns from the edit screen so the parent
  /// can refresh the fetched profile and re-render with the new data.
  final VoidCallback? onEdited;

  String _orDash(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty ? '—' : s;
  }

  String get _dobLabel {
    final raw = profile.dateOfBirth;
    if (raw == null || raw.trim().isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat('d MMM y').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          vSpace(20),
          _InfoRow(label: 'First Name', value: _orDash(profile.firstName)),
          vSpace(16),
          // Middle name surfaces only when present — keeps the card
          // compact for users who don't have one, but never silently
          // drops it for those who do. Edit-profile always exposes it.
          if ((profile.middleName ?? '').trim().isNotEmpty) ...[
            _InfoRow(label: 'Middle Name', value: profile.middleName!),
            vSpace(16),
          ],
          _InfoRow(label: 'Last Name', value: _orDash(profile.lastName)),
          vSpace(16),
          _InfoRowWithIcon(
            icon: Icons.email_outlined,
            label: 'Email Address',
            value: _orDash(profile.email),
          ),
          vSpace(16),
          _InfoRowWithIcon(
            icon: Icons.phone_outlined,
            label: 'Phone Number',
            value: _orDash(profile.phone),
          ),
          vSpace(16),
          _InfoRowWithIcon(
            icon: Icons.calendar_today_outlined,
            label: 'Date of Birth',
            value: _dobLabel,
          ),
          vSpace(16),
          _InfoRowWithIcon(
            icon: Icons.work_outline,
            label: 'Occupation',
            value: _orDash(profile.occupation),
          ),
          vSpace(20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await context.pushNamed('edit-profile', extra: {
                  'profile': profile,
                });
                onEdited?.call();
              },
              icon: Icon(Icons.edit, size: 18.sp),
              label: const Text('Edit Profile'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF7434FF)),
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
            fontSize: 17.sp,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            hSpace(8),
            Text(
              label,
              style: TextStyle(
                fontSize: 17.sp,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
