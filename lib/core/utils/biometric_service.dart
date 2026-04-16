import 'package:local_auth/local_auth.dart';
import 'dart:io';

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if the device supports biometric authentication
  static Future<bool> isBiometricAvailable() async {
    try {
      // Check if device is supported
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      if (!isDeviceSupported) {
        return false;
      }

      // Check if we can check biometrics
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      if (!canCheckBiometrics) {
        return false;
      }

      // Check if there are any enrolled biometrics
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      return availableBiometrics.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get the biometric type available on the device
  static Future<String?> getBiometricType() async {
    try {
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      if (availableBiometrics.isEmpty) {
        return null;
      }

      // Check for Face ID (iOS) or Face (Android)
      if (availableBiometrics.contains(BiometricType.face)) {
        return Platform.isIOS ? 'Face ID' : 'Face';
      }

      // Check for fingerprint
      if (availableBiometrics.contains(BiometricType.fingerprint)) {
        return 'Fingerprint';
      }

      // Check for other biometric types
      if (availableBiometrics.contains(BiometricType.strong)) {
        return 'Biometric';
      }

      if (availableBiometrics.contains(BiometricType.weak)) {
        return 'Biometric';
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get user-friendly biometric name
  static Future<String> getBiometricName() async {
    final type = await getBiometricType();
    if (type == null) {
      return 'Biometric';
    }
    return type;
  }
}

