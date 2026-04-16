import 'dart:async';
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
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    
    // Setup animation only for progress bar
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

    // Failsafe: if initApp is slow or never navigates, still leave splash using the same
    // rules as SplashCubit (token → welcome-back for PIN, not logged-out welcome).
    _navigationTimer = Timer(const Duration(seconds: 10), () async {
      if (!mounted) return;
      if (GoRouterState.of(context).uri.path != '/') return;

      const storage = FlutterSecureStorage();
      final onboarding = await storage.read(key: 'onboarding_completed');
      final token = await storage.read(key: 'token');
      if (!mounted) return;

      final isFirstTime = onboarding != 'true';
      if (isFirstTime) {
        print('⚠️ SPLASH - Failsafe → /onboarding');
        context.go('/onboarding');
        return;
      }
      if (token != null && token.isNotEmpty) {
        print('⚠️ SPLASH - Failsafe → /welcome-back (token present)');
        context.go('/welcome-back', extra: {
          'phone': '',
          'method': 'fingerprint',
          'isAppLock': true,
        });
        return;
      }
      print('⚠️ SPLASH - Failsafe → /welcome (no token)');
      context.go('/welcome');
    });

    // Try to initialize app (but don't block navigation)
    context.read<SplashCubit>().initApp().catchError((error) {
      print('❌ SPLASH - Error in initApp: $error');
      // Ignore errors - timer will handle navigation
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _navigationTimer?.cancel();
    super.dispose();
  }

  void _handleState(BuildContext context, SplashState state) {
    print('🔵 SPLASH - State received: ${state.runtimeType}');
    
    if (state is SplashNoInternet) {
      // ConnectivityListener will handle showing the persistent snackbar
      // The NetworkInterceptor will wait for connectivity before making API calls
      // Don't navigate yet - wait for connectivity to be restored
      print('🔵 SPLASH - No internet, waiting...');
    } else if (state is SplashFirstTimeUser) {
      print('🔵 SPLASH - First time user, navigating to /onboarding');
      _navigationTimer?.cancel();
      context.go('/onboarding');
    } else if (state is SplashLoggedOut) {
      print('🔵 SPLASH - Logged out, navigating to /welcome');
      _navigationTimer?.cancel();
      context.go('/welcome');
    } else if (state is SplashLoggedIn) {
      print('🔵 SPLASH - Logged in, navigating to /welcome-back');
      _navigationTimer?.cancel();
      // Navigate to welcome-back screen for password/biometric authentication
      // User is logged in but unauthorized, so hide back button
      context.go('/welcome-back', extra: {
        'phone': '', // Not needed for app lock flow
        'method': 'fingerprint', // Default to biometric
        'isAppLock': true, // Hide back button for logged-in but unauthorized users
      });
    } else if (state is SplashError) {
      print('❌ SPLASH - Error: ${state.message}');
      // Show error but let timer continue to navigate
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.message)));
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
          child: BlocListener<SplashCubit, SplashState>(
          listener: _handleState,
            child: Stack(
              children: [
              // Background with blurred glows
              _buildBackgroundGlows(),

              // Main content (static - no animations)
              Center(
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // White circle with logo
                    _buildLogoCircle(),

                    vSpace(40),

                    // App name
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

                    // Tagline
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

                    // Animated loading indicator (only this animates)
                    _buildLoadingIndicator(),
                  ],
                ),
              ),
              ],
            ),
            ),
          ),
      ),
    );
  }

  Widget _buildBackgroundGlows() {
    return Center(
      child: SizedBox(
        width: 400.w,
        height: 650.h,
        child: Stack(
                    children: [
            // Orange/Yellow glow - top right area
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

            // Light purple/pink glow - left side
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

            // Blue/Cyan glow - bottom right
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

            // Blur effect for soft glow appearance
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
                Color(0xFF00D9FF), // Cyan
                Color(0xFF00A8E8),
                Color(0xFFFFC107), // Yellow/Orange
              ],
              stops: [0.0, _progressAnimation.value, 1.0],
            ),
          ),
        );
      },
    );
  }
}
