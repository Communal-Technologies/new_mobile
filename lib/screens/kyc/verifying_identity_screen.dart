import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:go_router/go_router.dart';

class VerifyingIdentityScreen extends StatefulWidget {
  const VerifyingIdentityScreen({super.key});

  @override
  State<VerifyingIdentityScreen> createState() =>
      _VerifyingIdentityScreenState();
}

class _VerifyingIdentityScreenState extends State<VerifyingIdentityScreen> {
  double _progress = 0.0;
  Timer? _timer;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _startVerification();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startVerification() {
    const totalDuration = 6; // 6 seconds
    const updateInterval = Duration(milliseconds: 100);
    var elapsed = 0;

    _timer = Timer.periodic(updateInterval, (timer) {
      elapsed += updateInterval.inMilliseconds;
      final progress = elapsed / (totalDuration * 1000);

      setState(() {
        _progress = progress.clamp(0.0, 1.0);

        // Update current step based on progress
        if (_progress < 0.33) {
          _currentStep = 0;
        } else if (_progress < 0.66) {
          _currentStep = 1;
        } else {
          _currentStep = 2;
        }
      });

      if (_progress >= 1.0) {
        timer.cancel();
        // Navigate to All Set screen
        if (mounted) {
          context.pushReplacement('/kyc/all-set');
        }
      }
    });
  }

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

                    // Large circular shield icon
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
                      'Verifying your identity',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),

                    vSpace(12),

                    // Subtitle
                    Text(
                      'Checking your documents and information',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),

                    vSpace(48),

                    // Progress steps
                    _buildProgressStep(
                      title: 'Verifying your identity',
                      isActive: _currentStep == 0,
                      isCompleted: _currentStep > 0,
                    ),
                    vSpace(12),
                    _buildProgressStep(
                      title: 'Setting up your account',
                      isActive: _currentStep == 1,
                      isCompleted: _currentStep > 1,
                    ),
                    vSpace(12),
                    _buildProgressStep(
                      title: 'Preparing your dashboard',
                      isActive: _currentStep == 2,
                      isCompleted: false,
                    ),

                    const Spacer(),

                    // Multi-colored progress bar
                    _buildProgressBar(),

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

  Widget _buildProgressStep({
    required String title,
    required bool isActive,
    required bool isCompleted,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        gradient: isActive
            ? LinearGradient(
                colors: [
                  const Color(0xFF00D9FF).withValues(alpha: 0.3),
                  const Color(0xFF3B82F6).withValues(alpha: 0.25),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: !isActive ? Colors.white.withValues(alpha: 0.08) : null,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive || isCompleted
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.transparent,
              border: Border.all(
                color: Colors.white.withValues(alpha: isActive ? 0.5 : 0.3),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(
                isCompleted ? Icons.check : Icons.shield_outlined,
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
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: Colors.white.withValues(alpha: isActive ? 1.0 : 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    // Calculate the segments
    final segment1 = _progress.clamp(0.0, 0.5) / 0.5; // First 50% in teal-blue
    final segment2 = (_progress - 0.5).clamp(0.0, 0.5) / 0.5; // Next 50% in yellow-orange

    return Container(
      height: 8.h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        color: Colors.white.withValues(alpha: 0.15),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10.r),
        child: Row(
          children: [
            // Teal-blue segment (first 50%)
            Expanded(
              flex: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00D9FF).withValues(alpha: segment1),
                      const Color(0xFF3B82F6).withValues(alpha: segment1),
                    ],
                  ),
                ),
              ),
            ),
            // Yellow-orange segment (last 50%)
            Expanded(
              flex: 50,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFA500).withValues(alpha: segment2),
                      const Color(0xFFFFD700).withValues(alpha: segment2),
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
