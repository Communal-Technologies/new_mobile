import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:communal_mobile/cubits/splash/splash_cubit.dart';
import 'package:communal_mobile/cubits/splash/splash_state.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/connectivity_listener.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SplashCubit>().initApp();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onSplashStateForNavigation(BuildContext context, SplashState state) {
    if (state is SplashFirstTimeUser) {
      context.go('/onboarding');
    } else if (state is SplashLoggedOut) {
      context.go('/welcome');
    } else if (state is SplashLoggedIn) {
      context.go('/welcome-back', extra: {
        'phone': '',
        'method': 'fingerprint',
        'isAppLock': true,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: primaryColor,
        body: ConnectivityListener(
          persistentOfflineSnackbar: true,
          child: BlocConsumer<SplashCubit, SplashState>(
            listenWhen: (prev, next) =>
                next is SplashFirstTimeUser ||
                next is SplashLoggedOut ||
                next is SplashLoggedIn,
            listener: _onSplashStateForNavigation,
            builder: (context, state) {
              final showBlockingError = state is SplashError;
              final errorMessage =
                  showBlockingError ? state.message : '';
              final waitingOffline = state is SplashNoInternet;

              return Stack(
                children: [
                  _buildSplashContent(primaryColor),
                  if (waitingOffline)
                    Positioned(
                      left: 24.w,
                      right: 24.w,
                      bottom: 48.h,
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          'No internet connection. Connect to Wi‑Fi or mobile data to continue.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  if (showBlockingError)
                    Positioned.fill(
                      child: Container(
                        color: primaryColor.withValues(alpha: 0.97),
                        child: SafeArea(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 28.w),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_off_outlined,
                                  size: 56.sp,
                                  color: Colors.white,
                                ),
                                vSpace(20),
                                Text(
                                  'We couldn\'t reach Communal',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                vSpace(12),
                                Text(
                                  errorMessage,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14.sp,
                                    height: 1.35,
                                  ),
                                ),
                                vSpace(28),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: primaryColor,
                                      padding: EdgeInsets.symmetric(vertical: 14.h),
                                    ),
                                    onPressed: () {
                                      context.read<SplashCubit>().initApp();
                                    },
                                    child: const Text('Try again'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSplashContent(Color primaryColor) {
    return Stack(
      children: [
        _buildBackgroundGlows(),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogoCircle(),
              vSpace(40),
              Text(
                'Communal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 40.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              vSpace(12),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40.w),
                child: Text(
                  'Building communities through cooperation',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              vSpace(40),
              _buildLoadingIndicator(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackgroundGlows() {
    return Center(
      child: SizedBox(
        width: 400.w,
        height: 650.h,
        child: Stack(
          children: [
            Positioned(
              top: 20.h,
              right: 10.w,
              child: Container(
                width: 200.w,
                height: 200.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.orange.withValues(alpha: 0.5),
                      Colors.orange.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 180.h,
              left: 0.w,
              child: Container(
                width: 180.w,
                height: 180.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE0B0FF).withValues(alpha: 0.5),
                      const Color(0xFFB09FFF).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 50.h,
              right: 20.w,
              child: Container(
                width: 190.w,
                height: 190.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.cyan.withValues(alpha: 0.5),
                      Colors.blue.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
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

  Widget _buildLogoCircle() {
    return Container(
      width: 200.w,
      height: 200.w,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Center(
        child: Image.asset(
          Images.coloredLogo,
          width: 140.w,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Container(
          width: 120.w,
          height: 4.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: const [
                Color(0xFF00D9FF),
                Color(0xFF00A8E8),
                Color(0xFFFFC107),
              ],
              stops: [0.0, _progressAnimation.value, 1.0],
            ),
          ),
        );
      },
    );
  }
}
