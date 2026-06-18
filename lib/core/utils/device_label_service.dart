import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// Returns a short human-readable device label for use in the User-Agent
/// header, e.g. "Pixel 7 Pro" (Android) or "iPhone 15 Pro" (iOS).
/// Falls back to the OS name when the model is unavailable.
Future<String> getDeviceLabel() async {
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final a = await info.androidInfo;
      final model = a.model.trim();
      final release = a.version.release.trim();
      if (model.isNotEmpty) {
        return release.isNotEmpty ? '$model; Android $release' : model;
      }
      return 'Android${release.isNotEmpty ? ' $release' : ''}';
    } else if (Platform.isIOS) {
      final i = await info.iosInfo;
      final name = i.utsname.machine.trim(); // e.g. "iPhone16,1"
      final systemVersion = i.systemVersion.trim();
      // Use the human-readable name when available (e.g. "iPhone 15 Pro").
      final readable = i.name.trim();
      final label = readable.isNotEmpty ? readable : (name.isNotEmpty ? name : 'iPhone');
      return systemVersion.isNotEmpty ? '$label; iOS $systemVersion' : label;
    }
  } catch (_) {}
  return Platform.operatingSystem;
}
