import 'package:communal_mobile/screens/onboarding/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:communal_mobile/cubits/splash/splash_cubit.dart';
import 'package:communal_mobile/cubits/splash/splash_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SplashCubit>().initApp();
  }

  void _handleState(BuildContext context, SplashState state) {
    if (state is SplashNoInternet) {
      // Show a retry dialog or offline screen
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("No Internet Connection")));
    } else if (state is SplashFirstTimeUser) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnBoardingScreen()),
      );
    } else if (state is SplashLoggedOut) {
      Navigator.pushReplacementNamed(context, '/welcome');
    } else if (state is SplashLoggedIn) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (state is SplashError) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        body: BlocListener<SplashCubit, SplashState>(
          listener: _handleState,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(Images.whiteLogo, width: 300, height: 312),
                    ],
                  ),
                ),
                const Positioned(
                  bottom: 70.0,
                  child: SpinKitSpinningLines(color: Colors.white, size: 70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
