import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// `ThemeData.fontFamily` only reaches `textTheme` and `primaryTextTheme`.
  /// Anything that sets a `TextStyle` of its own — `appBarTheme.titleTextStyle`
  /// below — has to name the family itself, or it silently resolves to whatever
  /// the device ships as its system font. That is why every screen's header used
  /// to read in the device font while its body read in Sen.
  static final String? _fontFamily = GoogleFonts.sen().fontFamily;

  static const Color _primary = Color(0xFF742CE7);
  static const Color _lightSurface = Color(0xFFF8F8FB);
  static const Color _darkBg = Color(0xFF0F0F14);
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkSurfaceVariant = Color(0xFF2A2A33);

  /// Light theme
  static final ThemeData light = ThemeData(
    fontFamily: GoogleFonts.sen().fontFamily,
    brightness: Brightness.light,
    primaryColor: _primary,
    scaffoldBackgroundColor: _lightSurface,
    canvasColor: Colors.white,
    secondaryHeaderColor: const Color(0xFFB09FFF),
    dividerColor: const Color(0xFFECECEB),
    cardColor: Colors.white,
    hintColor: const Color(0xFF9F9F9F),
    disabledColor: const Color(0xFFBABFC4),
    shadowColor: Colors.grey[300],
    pageTransitionsTheme: transitions,
    textTheme: textTheme.apply(
      bodyColor: const Color(0xFF0F1D40),
      displayColor: const Color(0xFF0F1D40),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: const Color(0xFF0F1D40),
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      iconTheme: const IconThemeData(color: Color(0xFF0F1D40)),
      titleTextStyle: TextStyle(
        fontFamily: _fontFamily,
        color: const Color(0xFF0F1D40),
        fontWeight: FontWeight.w700,
        fontSize: 19,
      ),
      toolbarTextStyle: TextStyle(
        fontFamily: _fontFamily,
        color: const Color(0xFF0F1D40),
      ),
    ),
    colorScheme: const ColorScheme.light(
      primary: _primary,
      secondary: Color(0xFFB09FFF),
      surface: Colors.white,
      onSurface: Color(0xFF0F1D40),
      onPrimary: Colors.white,
      surfaceContainerHighest: Color(0xFFF3F3F9),
    ),
  );

  /// Dark theme
  static final ThemeData dark = ThemeData(
    fontFamily: GoogleFonts.sen().fontFamily,
    brightness: Brightness.dark,
    primaryColor: _primary,
    scaffoldBackgroundColor: _darkBg,
    canvasColor: _darkSurface,
    secondaryHeaderColor: const Color(0xFFB09FFF),
    dividerColor: const Color(0xFF2C2C2C),
    cardColor: _darkSurface,
    hintColor: const Color(0xFF9F9F9F),
    disabledColor: const Color(0xFF555555),
    shadowColor: Colors.black26,
    pageTransitionsTheme: transitions,
    textTheme: textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        fontFamily: _fontFamily,
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 19,
      ),
      toolbarTextStyle: TextStyle(
        fontFamily: _fontFamily,
        color: Colors.white,
      ),
    ),
    colorScheme: const ColorScheme.dark(
      primary: _primary,
      secondary: Color(0xFFB09FFF),
      surface: _darkSurface,
      onSurface: Colors.white,
      onPrimary: Colors.white,
      surfaceContainerHighest: _darkSurfaceVariant,
    ),
  );
}
