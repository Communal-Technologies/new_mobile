import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controls whether screenshots and screen recording are allowed.
///
/// On Android this wraps `FLAG_SECURE` (Windows manager flag that prevents
/// screenshots and screen recording, and blacks out the app in the recents
/// switcher). On iOS there is no direct equivalent — the system-level
/// snapshot is already blocked by the privacy overlay in `AppDelegate`.
///
/// The preference is persisted to [SharedPreferences] under [_prefKey] and
/// re-applied on every cold start via [applyFromPrefs].
class ScreenshotService {
  static const MethodChannel _channel =
      MethodChannel('elite.codec.communal/screenshot');
  static const String _prefKey = 'allow_screenshot';

  ScreenshotService._();

  /// Returns the currently persisted value (default: screenshots disabled).
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// Sets the screenshot permission and persists the choice.
  static Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>(
        'setScreenshotEnabled',
        <String, dynamic>{'enabled': enabled},
      );
    } on MissingPluginException {
      // Silently ignore on unsupported platforms (web, desktop previews).
    } on PlatformException {
      // Log is suppressed in release; best-effort.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }

  /// Reads the saved preference and applies it. Call once on app start so
  /// the FLAG_SECURE state matches what the user last configured.
  static Future<void> applyFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_prefKey) ?? false;
    try {
      await _channel.invokeMethod<void>(
        'setScreenshotEnabled',
        <String, dynamic>{'enabled': enabled},
      );
    } on MissingPluginException {
      // Unsupported platform — skip silently.
    } on PlatformException {
      // Best effort.
    }
  }
}
