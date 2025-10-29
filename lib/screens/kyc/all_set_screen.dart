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
            // Background glows with blur
            _buildBackgroundGlows(),

            // Content
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
                child: Column(
                  children: [
                    const Spacer(),

                    // Large circular shield icon with frosted glass effect
                    Container(
                      width: 160.w,
                      height: 160.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.shield_outlined,
                          size: 80.sp,
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
                      'Your account has been created successfully, Welcome to communal.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white.withValues(alpha: 0.9),
                        height: 1.4,
                      ),
                    ),

                    vSpace(48),

                    // Setup steps (NO checkmarks or completion indicators)
                    _buildSetupStep(
                      icon: Icons.shield_outlined,
                      title: 'Verifying your identity',
                    ),
                    vSpace(12),
                    _buildSetupStep(
                      icon: Icons.grid_view_outlined,
                      title: 'Setting up your account',
                    ),
                    vSpace(12),
                    _buildSetupStep(
                      icon: Icons.dashboard_outlined,
                      title: 'Preparing your dashboard',
                    ),

                    const Spacer(),

                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 56.h,
                      child: ElevatedButton(
                        onPressed: () {
                          context.go('/home');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28.r),
                          ),
                        ),
                        child: Text(
                          'Continue to Dashboard',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    vSpace(32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetupStep({
    required IconData icon,
    required String title,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.12),
            Colors.white.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          // Icon with blue border (NO checkmark)
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF00D9FF),
                width: 2,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
          ),
          hSpace(12),
          // Title
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w400,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
        child: Stack(
          children: [
            // Light purple glow - top center
            Positioned(
              top: 100.h,
              left: 100.w,
              child: Container(
                width: 250.w,
                height: 250.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE0B0FF).withValues(alpha: 0.4),
                      const Color(0xFFB09FFF).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Blue glow - bottom right
            Positioned(
              bottom: 150.h,
              right: -50.w,
              child: Container(
                width: 220.w,
                height: 220.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00D9FF).withValues(alpha: 0.35),
                      const Color(0xFF3B82F6).withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
