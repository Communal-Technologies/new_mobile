import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';

class FreezeAccountSuccessScreen extends StatelessWidget {
  const FreezeAccountSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Freeze Account',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4), size: 20.sp),
              onPressed: () {},
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Container(
            margin: EdgeInsets.all(16.w),
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 80.w,
                  height: 80.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7434FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.pause_circle_outline,
                    color: Colors.white,
                    size: 50.sp,
                  ),
                ),
                vSpace(32),
                Text(
                  'Account Frozen Successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                vSpace(16),
                Text(
                  'Your account has been temporarily disabled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
                vSpace(4),
                Text(
                  'All transactions are blocked.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 19.sp,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                ),
                vSpace(32),
                _buildConfirmationEmailCard(context),
                vSpace(40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate back to account settings
                      context.goNamed('account-settings');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7434FF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    child: Text(
                      'Okay, Go back to settings',
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationEmailCard(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: const Color(0xFF7434FF).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.email_outlined,
              color: const Color(0xFF7434FF),
              size: 22.sp,
            ),
          ),
          hSpace(12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 17.sp,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                children: [
                  const TextSpan(text: 'A confirmation email has been sent to '),
                  TextSpan(
                    text: 'pado.lebari@example.com',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

