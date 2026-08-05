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

    // The badge disc and the button both sit on cardColor, which is near-black
    // in dark mode — so a primaryColor label/icon on it is purple-on-black.
    final onCard = theme.brightness == Brightness.dark
        ? Colors.white
        : theme.primaryColor;

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
                  _SuccessBadge(theme: theme, checkColor: onCard),

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
                        backgroundColor: theme.cardColor,
                        foregroundColor: onCard,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28.r),
                        ),
                      ),
                      child: Text(
                        'Continue to Verify Account',
                        style: TextStyle(
                          color: onCard,
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

  // Mirrors the splash screen's arrangement: the glows are laid out first and
  // the BackdropFilter is the LAST child, so it blurs the circles painted
  // beneath it. Nesting them inside the filter (as this screen used to) blurs
  // whatever is behind the filter instead, leaving the circles hard-edged.
  Widget _buildBackgroundGlows() {
    return Positioned.fill(
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              top: -40.h,
              left: -60.w,
              child: _glow(
                220,
                const Color(0xFFE0B0FF),
                const Color(0xFFB09FFF),
              ),
            ),

            Positioned(
              top: 260.h,
              right: -70.w,
              child: _glow(
                240,
                const Color(0xFF00D9FF),
                const Color(0xFF3B82F6),
              ),
            ),

            Positioned(
              bottom: -50.h,
              left: -30.w,
              child: _glow(200, Colors.orange, Colors.deepOrange),
            ),

            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: Colors.transparent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(double size, Color inner, Color outer) {
    return Container(
      width: size.w,
      height: size.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            inner.withValues(alpha: 0.55),
            outer.withValues(alpha: 0.3),
            Colors.transparent,
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
  const _SuccessBadge({required this.theme, required this.checkColor});

  final ThemeData theme;
  final Color checkColor;

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
                  color: checkColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

