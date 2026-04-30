import 'package:flutter/material.dart';
import 'package:communal_mobile/core/utils/system_ui_style.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:communal_mobile/core/constants/images.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:communal_mobile/core/widgets/space.dart';
import 'package:communal_mobile/core/widgets/app_elevated_button.dart';
import 'package:communal_mobile/screens/onboarding/widgets/indicator.dart';

const Color _onboardingHeadingLight = Color(0xFF3E28A2);

class OnBoardingScreen extends StatefulWidget {
  const OnBoardingScreen({super.key});

  @override
  State<OnBoardingScreen> createState() => _OnBoardingScreenState();
}

class _OnBoardingScreenState extends State<OnBoardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<Map<String, String>> onboardingData = [
    {
      'text': 'Create a shared financial adventure',
      'image': Images.onBoardingOne,
    },
    {'text': 'Your new financial playground', 'image': Images.onBoardingTwo},
    {'text': 'Find your Community', 'image': Images.onBoardingThree},
  ];

  void _onNextPressed() {
    if (_currentIndex < onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _onSkip() {
    _completeOnboarding();
  }

  void _completeOnboarding() async {
    // Persist onboarding complete flag in secure storage (app-level setting, not user data)
    // This will persist through logout but be cleared on app uninstall
    const secureStorage = FlutterSecureStorage();
    await secureStorage.write(key: 'onboarding_completed', value: 'true');

    if (!mounted) return;
    context.goNamed('welcome');
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayForTheme(Theme.of(context)),
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: onboardingData.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return OnboardingPage(
                    index: index,
                    text: onboardingData[index]['text']!,
                    image: onboardingData[index]['image']!,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  vSpace(10),
                  OnboardingIndicator(
                    currentIndex: _currentIndex,
                    total: onboardingData.length,
                  ),
                  vSpace(20),
                  _currentIndex != onboardingData.length - 1
                      ? Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                height: 50.h,
                                child: Builder(
                                  builder: (context) {
                                    final isDark =
                                        Theme.of(context).brightness ==
                                            Brightness.dark;
                                    final skipColor = isDark
                                        ? Colors.white
                                        : Theme.of(context).primaryColor;
                                    return OutlinedButton(
                                      onPressed: _onSkip,
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          width: 2,
                                          color: skipColor,
                                        ),
                                        foregroundColor: skipColor,
                                        surfaceTintColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(25.r),
                                        ),
                                        padding:
                                            EdgeInsets.symmetric(vertical: 14.h),
                                      ),
                                      child: Text(
                                        'Skip',
                                        style: TextStyle(
                                          fontSize: 17.sp,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                          color: skipColor,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            hSpace(10),
                            Expanded(
                              flex: 2,
                              child: AppElevatedButton(
                                title: 'Next',
                                onPressed: _onNextPressed,
                              ),
                            ),
                          ],
                        )
                      : AppElevatedButton(
                          title: "Let's Go",
                          onPressed: _onNextPressed,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final int index;
  final String text;
  final String image;

  const OnboardingPage({
    super.key,
    required this.index,
    required this.text,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headingColor = isDark ? Colors.white : _onboardingHeadingLight;
    return SafeArea(
      child: Stack(
        children: [
          Center(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 70),
                  child: Image.asset(
                    isDark ? Images.whiteLogo : Images.coloredLogo,
                    height: 71,
                    width: 250,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: index == 2 ? 50 : 60,
                    vertical: 20,
                  ),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall!.copyWith(
                      fontSize: index == 2 ? 48 : 24,
                      color: headingColor,
                      shadows: index == 2
                          ? [
                              BoxShadow(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: 0.19),
                                offset: const Offset(11, 10),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
                Image.asset(image, height: 300, width: 300),
              ],
            ),
          ),
          if (index == 2)
            Positioned(
              top: 158,
              left: 0,
              child: Image.asset(Images.cake, width: 70, height: 52),
            ),
          if (index == 2)
            Positioned(
              bottom: 0,
              right: 0,
              child: Image.asset(Images.cake, width: 70, height: 52),
            ),
        ],
      ),
    );
  }
}
