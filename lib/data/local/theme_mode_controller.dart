import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent app-wide theme switcher.
///
/// Holds the current [ThemeMode] and persists it across launches via
/// SharedPreferences. Wired into the root [MaterialApp.router] so a flip
/// here re-renders every screen with the matching colour scheme. The
/// settings-screen toggle reads + writes through this controller; the
/// boolean-shaped UI maps `light` ↔ `dark` (we don't yet expose
/// [ThemeMode.system] in the toggle, but the controller supports it for
/// a future "Match system" tile).
class ThemeModeController extends ChangeNotifier {
  ThemeModeController(this._prefs) {
    _mode = _read();
  }

  final SharedPreferences _prefs;
  static const String _key = 'app_theme_mode';

  late ThemeMode _mode;

  ThemeMode get mode => _mode;
  bool get isDarkMode => _mode == ThemeMode.dark;

  Future<void> setDarkMode(bool dark) async {
    final next = dark ? ThemeMode.dark : ThemeMode.light;
    if (next == _mode) return;
    _mode = next;
    await _prefs.setString(_key, _serialize(next));
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    await _prefs.setString(_key, _serialize(mode));
    notifyListeners();
  }

  ThemeMode _read() {
    final raw = _prefs.getString(_key);
    switch (raw) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      case 'light':
      default:
        return ThemeMode.light;
    }
  }

  String _serialize(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }
}
