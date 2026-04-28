import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class DeleteAccountWarningSection extends StatelessWidget {
  const DeleteAccountWarningSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100.w,
          height: 100.w,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.red.shade300,
              width: 2,
            ),
          ),
          child: Icon(
            Icons.delete,
            color: Colors.red,
            size: 50.sp,
          ),
        ),
        vSpace(24),
        Text(
          'Are you sure you want to Delete your Account?',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F1D40),
          ),
          textAlign: TextAlign.center,
        ),
        vSpace(12),
        Text(
          'This action is permanent and cannot be undone. All your data will be permanently deleted.',
          style: TextStyle(
            fontSize: 15.sp,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

