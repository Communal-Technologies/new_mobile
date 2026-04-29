import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status-bar overlay style that follows the active brightness — dark
/// icons on a light scaffold, light icons on a dark scaffold. Most
/// screens hardcoded `SystemUiOverlayStyle.dark` which works in light
/// mode but renders an invisible status bar after the dark-mode flip.
SystemUiOverlayStyle systemOverlayForTheme(ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: theme.scaffoldBackgroundColor,
    systemNavigationBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
  );
}
