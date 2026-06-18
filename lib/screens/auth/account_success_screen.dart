import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/navigation/kyc_resume.dart';
import 'package:communal_mobile/core/widgets/space.dart';

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
                  const Spacer(flex: 3),

                  // Layered success badge: soft outer halo → translucent
                  // ring → solid white disc with the brand-coloured check.
                  _SuccessBadge(theme: theme),

                  vSpace(36),

                  // Success message
                  Text(
                    'Account Created\nSuccessfully',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.25,
                      letterSpacing: 0.2,
                    ),
                  ),

                  vSpace(14),

                  // Description
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Text(
                      'Your account has been created successfully. Verify it with your NIN or BVN to activate your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18.sp,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.55,
                      ),
                    ),
                  ),

                  const Spacer(flex: 4),

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

/// Layered "success" badge — a solid white disc holding the brand check,
/// wrapped in two translucent rings that give it a soft glowing depth
/// against the purple background.
class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168.w,
      height: 168.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
      ),
      child: Center(
        child: Container(
          width: 132.w,
          height: 132.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.16),
          ),
          child: Center(
            child: Container(
              width: 96.w,
              height: 96.w,
              decoration: BoxDecoration(
                color: theme.cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.check_rounded,
                  size: 58.sp,
                  color: theme.primaryColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

