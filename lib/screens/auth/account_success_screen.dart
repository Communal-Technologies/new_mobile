import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/navigation/kyc_resume.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class AccountSuccessScreen extends StatelessWidget {
  const AccountSuccessScreen({super.key});

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
          // Background glows (similar to splash screen)
          _buildBackgroundGlows(),

          // Content
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
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

                  vSpace(40),

                  // Success icon
                  Container(
                    width: 120.w,
                    height: 120.w,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.check,
                        size: 70.sp,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),

                  vSpace(24),

                  // Success message
                  Text(
                    'Account Created\nSuccessfully',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),

                  vSpace(12),

                  // Description
                  Text(
                    'Your account has been created successfully, verify your account with your NIN or BVN to activate you account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 19.sp,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.5,
                    ),
                  ),

                  vSpace(40),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: 56.h,
                    child: ElevatedButton(
                      onPressed: () => pushKycResumeRoute(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).cardColor,
                        foregroundColor: theme.primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28.r),
                        ),
                      ),
                      child: Text(
                        'Continue to Verify Account',
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),
                  vSpace(24),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
        child: Stack(
          children: [
            // Light purple/pink glow - behind content area (left side)
            Positioned(
              top: 200.h,
              left: 20.w,
              child: Container(
                width: 200.w,
                height: 200.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE0B0FF).withValues(alpha: 0.5),
                      const Color(0xFFB09FFF).withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Bright blue glow - behind content area (right side)
            Positioned(
              top: 300.h,
              right: 20.w,
              child: Container(
                width: 200.w,
                height: 200.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF00D9FF).withValues(alpha: 0.5),
                      const Color(0xFF3B82F6).withValues(alpha: 0.3),
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

