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
              Icons.touch_app_outlined,
              size: 48.sp,
              color: Theme.of(context).primaryColor,
            ),
            vSpace(16),
            Text(
              'Are you still there?',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w700,
                color: Colors.black,
              ),
            ),
            vSpace(8),
            Text(
              'You\'ve been idle for a while. Tap Stay to continue, or Leave to lock the app.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.sp,
                color: Colors.grey.shade600,
              ),
            ),
            vSpace(24),
            AppElevatedButton(
              title: 'Stay',
              onPressed: () {
                context.read<SecurityCubit>().resetIdle();
                Navigator.of(context).pop();
              },
            ),
            vSpace(12),
            AppSecondaryButton(
              title: 'Leave',
              isDark: false,
              onPressed: () {
                Navigator.of(context).pop();
                // Same as idle timeout: keep session token, require PIN again.
                context.read<SecurityCubit>().lockApp(isIdleTimeout: true);
              },
            ),
          ],
        ),
      ),
    );
  }
}

