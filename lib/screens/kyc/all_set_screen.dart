import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class AllSetScreen extends StatelessWidget {
  const AllSetScreen({super.key});

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
                  const Spacer(),

                  // Shield icon
                  Container(
                    width: 140.w,
                    height: 140.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.shield_outlined,
                        size: 70.sp,
                        color: Colors.white,
                      ),
                    ),
                  ),

                  vSpace(40),

                  // Title
                  Text(
                    'All Set!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 40.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),

                  vSpace(16),

                  // Subtitle
                  Text(
                    'Your account has been created successfully',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.white.withValues(alpha: 0.95),
                      height: 1.4,
                    ),
                  ),

                  vSpace(8),

                  Text(
                    'Welcome to communal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.white.withValues(alpha: 0.95),
                      height: 1.4,
                    ),
                  ),

                  vSpace(60),

                  // Completed steps
                  _buildCompletedStep(
                    icon: Icons.shield_outlined,
                    title: 'Verifying your identity',
                  ),
                  vSpace(16),
                  _buildCompletedStep(
                    icon: Icons.settings_outlined,
                    title: 'Setting up your account',
                  ),
                  vSpace(16),
                  _buildCompletedStep(
                    icon: Icons.dashboard_outlined,
                    title: 'Preparing your dashboard',
                  ),

                  const Spacer(),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: 50.h,
                    child: ElevatedButton(
                      onPressed: () {
                        // TODO: Navigate to dashboard
                        context.go('/home');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: theme.primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25.r),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      child: Text(
                        'Continue to Dashboard',
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 16.sp,
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

  Widget _buildCompletedStep({
    required IconData icon,
    required String title,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF00D9FF),
            ),
            child: Center(
              child: Icon(
                Icons.check,
                color: Colors.white,
                size: 24.sp,
              ),
            ),
          ),
          hSpace(16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Stack(
      children: [
        // Light purple/pink glow - top
        Positioned(
          top: -100.h,
          left: -50.w,
          child: Container(
            width: 300.w,
            height: 300.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFE0B0FF).withValues(alpha: 0.3),
                  const Color(0xFFB09FFF).withValues(alpha: 0.15),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Blue/Cyan glow - bottom
        Positioned(
          bottom: -80.h,
          right: -60.w,
          child: Container(
            width: 280.w,
            height: 280.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.cyan.withValues(alpha: 0.3),
                  Colors.blue.withValues(alpha: 0.15),
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

