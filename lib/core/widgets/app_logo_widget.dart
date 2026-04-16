import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppLogoImage extends StatelessWidget {
  const AppLogoImage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Image(
      image: const AssetImage('assets/images/logo.png'),
      width: 228.w,
    );
  }
}