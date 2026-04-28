import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class AddressInformationCard extends StatelessWidget {
  const AddressInformationCard({super.key});

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
                Icons.location_on_outlined,
                color: const Color(0xFF7434FF),
                size: 20.sp,
              ),
              hSpace(8),
              Text(
                'Address Information',
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F1D40),
                ),
              ),
            ],
          ),
          vSpace(20),
          _AddressRow(label: 'Street Address', value: '123 Marina Street'),
          vSpace(16),
          _AddressRow(label: 'City', value: 'Lagos'),
          vSpace(16),
          _AddressRow(label: 'State', value: 'Lagos State'),
          vSpace(20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                context.pushNamed('edit-profile', extra: {'isAddressOnly': true});
              },
              icon: Icon(Icons.edit, size: 18.sp),
              label: Text('Edit Address'),
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

class _AddressRow extends StatelessWidget {
  final String label;
  final String value;

  const _AddressRow({
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

