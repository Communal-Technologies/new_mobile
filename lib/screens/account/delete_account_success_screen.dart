import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/screens/account/widgets/what_happens_next_item.dart';

/// The one screen in the app that stands without a session — the account it
/// belonged to no longer exists by the time this is shown, so nothing here
/// reads the auth state and every exit leads to the login screen.
class DeleteAccountSuccessScreen extends StatelessWidget {
  const DeleteAccountSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        backgroundColor: Theme.of(context).cardColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).cardColor,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Text(
            'Delete Account',
            style: TextStyle(
              fontSize: 19.sp,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  vSpace(32),
                  _buildSuccessIcon(),
                  vSpace(24),
                  _buildSuccessMessage(context),
                  vSpace(32),
                  _buildWhatHappensNext(context),
                  vSpace(32),
                  _buildCloseButton(context),
                  vSpace(32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return Container(
      width: 100.w,
      height: 100.w,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // Light green
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF4CAF50), // Darker green
          width: 2,
        ),
      ),
      child: const Icon(Icons.check, color: Color(0xFF4CAF50), size: 60),
    );
  }

  Widget _buildSuccessMessage(BuildContext context) {
    return Column(
      children: [
        Text(
          'Your Account Has Been Deleted',
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        vSpace(16),
        Text(
          'You have been signed out and can no longer sign in with these '
          'details.',
          style: TextStyle(
            fontSize: 17.sp,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        vSpace(8),
        // No recovery is offered because there is none: the deletion is not a
        // request an admin can reverse, and the previous copy promised a
        // support team that could bring the account back.
        Text(
          'We\'re sorry to see you go. This cannot be undone — you would need '
          'to open a new account to use Communal again.',
          style: TextStyle(
            fontSize: 17.sp,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        vSpace(16),
        Text(
          'Thank you for using our services!',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWhatHappensNext(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What Happens Next?',
          style: TextStyle(
            fontSize: 19.sp,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        vSpace(16),
        const WhatHappensNextItem(
          text: 'Your account is closed and your wallet is frozen — it can no '
              'longer send or receive money',
        ),
        vSpace(12),
        const WhatHappensNextItem(
          text: 'Your personal data is erased within 30 days. Your email and '
              'phone number are released then, so they can be used for a new '
              'account after that',
        ),
        vSpace(12),
        const WhatHappensNextItem(
          text: 'Records of money that moved through your account are kept for '
              'as long as the law requires',
        ),
      ],
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => context.go('/login'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF7434FF), // Purple
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
        child: Text(
          'Done',
          style: TextStyle(fontSize: 19.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
