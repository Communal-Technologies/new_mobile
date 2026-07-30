import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class PasswordResetSuccessScreen extends StatelessWidget {
  const PasswordResetSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: theme.primaryColor,
        body: Stack(
          children: [
          // Background glows
          _buildBackgroundGlows(),

          // Content
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 40.h),
              child: Column(
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                      ),
                      onPressed: () => context.pop(),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Shield with keyhole icon
                  Container(
                    width: 140.w,
                    height: 140.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 90.sp,
                            color: Colors.white,
                          ),
                          Icon(
                            Icons.key,
                            size: 40.sp,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),

                  vSpace(40),

                  // Success message
                  Text(
                    'Password Reset\nSuccessful',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),

                  vSpace(20),

                  // Description
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      children: [
                        Text(
                          'Your password has been successfully updated.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19.sp,
                            color: Colors.white.withValues(alpha: 0.95),
                            height: 1.5,
                          ),
                        ),
                        Text(
                          'You can now sign in with your new password.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 19.sp,
                            color: Colors.white.withValues(alpha: 0.95),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 3),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: () {
                        context.go('/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).cardColor,
                        foregroundColor: theme.primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      child: Text(
                        'Continue to Sign in',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),

                  vSpace(40),
                ],
              ),
            ),
          ),

        // Blur effect
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
          child: Container(
            color: Colors.transparent,
          ),
        ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(
      children: [
        // Light purple/pink glow - top left
        Positioned(
          top: -100.h,
          left: -80.w,
          child: Container(
            width: 280.w,
            height: 280.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFE0B0FF).withValues(alpha: 0.4),
                  const Color(0xFFB09FFF).withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Blue/Cyan glow - bottom right
        Positioned(
          bottom: -80.h,
          right: -70.w,
          child: Container(
            width: 260.w,
            height: 260.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.cyan.withValues(alpha: 0.4),
                  Colors.blue.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

