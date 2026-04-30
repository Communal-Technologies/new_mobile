import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/data/models/member_profile_details.dart';

class AddressInformationCard extends StatelessWidget {
  const AddressInformationCard({
    super.key,
    required this.profile,
    this.onEdited,
  });

  final MemberProfileDetails profile;
  final VoidCallback? onEdited;

  String _orDash(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty ? '—' : s;
  }

  String get _streetLine {
    final parts = [profile.addressLine1, profile.addressLine2]
        .map((s) => (s ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? '—' : parts.join(', ');
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
                Icons.location_on_outlined,
                color: const Color(0xFF7434FF),
                size: 20.sp,
              ),
              hSpace(8),
              Text(
                'Address Information',
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          vSpace(20),
          _AddressRow(label: 'Street Address', value: _streetLine),
          vSpace(16),
          _AddressRow(label: 'City', value: _orDash(profile.city)),
          vSpace(16),
          _AddressRow(label: 'LGA', value: _orDash(profile.lga)),
          vSpace(16),
          _AddressRow(label: 'State', value: _orDash(profile.state)),
          vSpace(16),
          _AddressRow(label: 'Postal Code', value: _orDash(profile.postalCode)),
          vSpace(20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await context.pushNamed('edit-profile', extra: {
                  'profile': profile,
                  'isAddressOnly': true,
                });
                onEdited?.call();
              },
              icon: Icon(Icons.edit, size: 18.sp),
              label: const Text('Edit Address'),
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

class _AddressRow extends StatelessWidget {
  final String label;
  final String value;

  const _AddressRow({required this.label, required this.value});

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
