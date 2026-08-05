import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:communal_mobile/blocs/auth/auth_bloc.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/core/widgets/space.dart';

class FreezeAccountSuccessScreen extends StatelessWidget {
  const FreezeAccountSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthBloc>().state;
    final email = auth is AuthAuthenticated
        ? (auth.user.email?.trim() ?? '')
        : '';

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(theme),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: theme.cardColor,
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
              color: theme.colorScheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        vSpace(48),
                        Container(
                          width: 80.w,
                          height: 80.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFF7434FF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.pause_circle_outline,
                            color: Colors.white,
                            size: 50.sp,
                          ),
                        ),
                        vSpace(24),
                        Text(
                          'Account Frozen Successfully',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        vSpace(12),
                        Text(
                          'Your account has been temporarily disabled. All transactions are blocked.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17.sp,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                            height: 1.5,
                          ),
                        ),
                        vSpace(28),
                        if (email.isNotEmpty)
                          _ConfirmationEmailCard(email: email),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.goNamed('account-settings'),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmationEmailCard extends StatelessWidget {
  const _ConfirmationEmailCard({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: const Color(0xFF7434FF).withValues(alpha: 0.1),
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                children: [
                  const TextSpan(
                    text: 'A confirmation email has been sent to ',
                  ),
                  TextSpan(
                    text: email,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
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
