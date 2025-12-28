import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/cubits/security/security_cubit.dart';

class IdlePromptDialog extends StatelessWidget {
  const IdlePromptDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 48.sp,
              color: Theme.of(context).primaryColor,
            ),
            vSpace(16),
            Text(
              'Are you still there?',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            vSpace(8),
            Text(
              'You\'ve been idle for a while. Tap "I\'m here" to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.grey.shade600,
              ),
            ),
            vSpace(24),
            AppElevatedButton(
              title: 'I\'m here',
              onPressed: () {
                context.read<SecurityCubit>().resetIdle();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

