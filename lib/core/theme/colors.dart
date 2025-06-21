import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:communal_mobile/core/utils/dimensions.dart';

class AppTheme {
  // Shared text styles (used by both themes)
  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontWeight: FontWeight.w300,
      fontSize: Dimensions.fontSizeDefault,
    ),
    displayMedium: TextStyle(
      fontWeight: FontWeight.w400,
      fontSize: Dimensions.fontSizeDefault,
    ),
    displaySmall: TextStyle(
      fontWeight: FontWeight.w500,
      fontSize: Dimensions.fontSizeDefault,
    ),
    headlineMedium: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: Dimensions.fontSizeDefault,
    ),
    headlineSmall: TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: Dimensions.fontSizeDefault,
    ),
    titleLarge: TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: Dimensions.fontSizeDefault,
    ),
    bodySmall: TextStyle(
      fontWeight: FontWeight.w900,
      fontSize: Dimensions.fontSizeDefault,
    ),
    titleMedium: TextStyle(fontSize: 15.0, fontWeight: FontWeight.w500),
    bodyMedium: TextStyle(fontSize: 12.0),
    bodyLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w600),
  );

  // Common transition style
  static const PageTransitionsTheme transitions = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: ZoomPageTransitionsBuilder(),
      TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
      TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
    },
  );

  /// Light theme
  static final ThemeData light = ThemeData(
    fontFamily: GoogleFonts.poppins().fontFamily,
    brightness: Brightness.light,
    primaryColor: const Color(0xFF742CE7),
    secondaryHeaderColor: const Color(0xFFB09FFF),
    dividerColor: const Color(0xFFECECEB),
    cardColor: Colors.white,
    hintColor: const Color(0xFF9F9F9F),
    disabledColor: const Color(0xFFBABFC4),
    shadowColor: Colors.grey[300],
    pageTransitionsTheme: transitions,
    textTheme: textTheme,
  );

  /// Dark theme
  static final ThemeData dark = ThemeData(
    fontFamily: GoogleFonts.poppins().fontFamily,
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF742CE7),
    secondaryHeaderColor: const Color(0xFFB09FFF),
    dividerColor: const Color(0xFF2C2C2C),
    cardColor: const Color(0xFF1E1E1E),
    hintColor: const Color(0xFF9F9F9F),
    disabledColor: const Color(0xFF555555),
    shadowColor: Colors.black26,
    pageTransitionsTheme: transitions,
    textTheme: textTheme,
  );
}
