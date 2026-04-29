import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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
        body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image
          Image.asset(
            Images.welcomeBg,
            fit: BoxFit.cover,
          ),

          // Gradient overlay (dark at bottom, fades to top)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.65),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
              child: Column(
                children: [
                  // Logo at top
                  _buildLogoSection(),

                  // Push main content to bottom
                  const Spacer(),

                  // Main content (welcome message, description, buttons) near footer
                  _buildMainContent(context, theme),

                  vSpace(150),

                  // Legal disclaimer at footer
                  _buildLegalDisclaimer(context, theme),

                  vSpace(16),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return Center(
      child: Image.asset(
        // Welcome screen sits over a dark photo + gradient overlay in
        // both themes, so the white mark is correct regardless of the
        // active brightness.
        Images.whiteLogo,
        width: 200.w,
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Welcome message
        Text(
          'Welcome to Communal',
          style: TextStyle(
            color: Colors.white,
            fontSize: 36.sp,
            fontWeight: FontWeight.w700,
            height: 1.2,
            letterSpacing: -0.5,
          ),
        ),

        vSpace(20),

        // Description
        Text(
          'A network of people building wealth together through cooperative saving, investments, and community support.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: 17.sp,
            fontWeight: FontWeight.w400,
            height: 1.6,
            letterSpacing: 0.2,
          ),
        ),

        vSpace(48),

        // Create account button
        AppElevatedButton(
          title: 'Create an account',
          onPressed: () {
            // Navigate to sign up
            context.push('/signup');
          },
        ),

        vSpace(16),

        // Sign in button (secondary style)
        AppSecondaryButton(
          title: 'Sign in',
          onPressed: () {
            // Navigate to login
            context.push('/login');
          },
        ),
      ],
    );
  }

  Widget _buildLegalDisclaimer(BuildContext context, ThemeData theme) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        // Welcome screen sits over a dark photo gradient regardless of
        // theme, so the disclaimer text always wants a light grey
        // (theme.onSurface inverts in dark mode and would render dark
        // on a dark photo — unreadable).
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 14.sp,
          height: 1.4,
        ),
        children: [
          const TextSpan(text: 'By continuing, you agree to our '),
          TextSpan(
            text: 'Terms of Service',
            style: TextStyle(
              color: const Color(0xFF00D9FF),
              decoration: TextDecoration.none,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // Navigate to Terms of Service
                // TODO: Implement navigation
              },
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: const Color(0xFF00D9FF),
              decoration: TextDecoration.none,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                // Navigate to Privacy Policy
                // TODO: Implement navigation
              },
          ),
        ],
      ),
    );
  }
}

