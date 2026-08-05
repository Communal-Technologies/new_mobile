import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

import 'package:communal_mobile/core/utils/app_logger.dart';

/// Audit M38: Dart-side wrapper around the `communal/biometric_keys`
/// platform channel implemented in `BiometricKeyChannel` (Android) /
/// `BiometricKeyChannel.swift` (iOS).
///
/// Surface
/// -------
/// - [isAvailable]      true when the device has a usable strong biometric.
/// - [generateKeyPair]  create a new ECDSA P-256 keypair for [deviceId];
///                      returns the PEM-encoded public key. The private
///                      key is permanently bound to the Keystore /
///                      Secure Enclave and to the user's *current*
///                      biometric enrollment — adding a new fingerprint
///                      / face permanently invalidates the key, forcing
///                      re-enrollment via the backend.
/// - [getPublicKeyPem]  return the existing key's PEM if one exists,
///                      else null. Useful for the launch-time check
///                      (does the device know its key?).
/// - [signWithBiometric] prompt biometric, sign [payload] (typically a
///                      challenge nonce), return base64 of the DER-encoded
///                      ECDSA signature. Throws [BiometricKeyException]
///                      with one of the documented codes on failure.
/// - [revoke]           delete the keypair from Keystore / Secure Enclave.
///                      Idempotent.
@lazySingleton
class BiometricKeyService {
  BiometricKeyService() : _channel = const MethodChannel('communal/biometric_keys');

  /// Test-only constructor that lets unit tests inject a mock channel.
  @visibleForTesting
  BiometricKeyService.withChannel(this._channel);

  // Mutable to allow [BiometricKeyService.withChannel] to inject a test
  // channel; the production constructor seals it on first set.
  // ignore: prefer_final_fields
  MethodChannel _channel;

  Future<bool> isAvailable() async {
    try {
      final r = await _channel.invokeMethod<bool>('isAvailable');
      return r ?? false;
    } catch (e) {
      AppLogger.warn('BiometricKey', 'isAvailable failed: $e');
      return false;
    }
  }

  Future<String> generateKeyPair(String deviceId) async {
    final pem = await _invoke<String>(
      'generateKeyPair',
      <String, dynamic>{'deviceId': deviceId},
    );
    if (pem == null || pem.isEmpty) {
      throw const BiometricKeyException('NATIVE', 'no public key returned');
    }
    return pem;
  }

  Future<String?> getPublicKeyPem(String deviceId) async {
    return _invoke<String>(
      'getPublicKeyPem',
      <String, dynamic>{'deviceId': deviceId},
    );
  }

  /// Returns the base64 of the DER-encoded ECDSA signature over [payload].
  ///
  /// The native side prompts the system biometric UI; user-cancellation
  /// surfaces as [BiometricKeyException] with code `USER_CANCELED`.
  Future<String> signWithBiometric({
    required String deviceId,
    required String payload,
    String promptTitle = 'Confirm with biometrics',
    String promptSubtitle =
        "Verify it's you to authorize this transaction",
    String promptNegativeButton = 'Cancel',
  }) async {
    final sig = await _invoke<String>(
      'signWithBiometric',
      <String, dynamic>{
        'deviceId': deviceId,
        'payload': payload,
        'promptTitle': promptTitle,
        'promptSubtitle': promptSubtitle,
        'promptNegativeButton': promptNegativeButton,
      },
    );
    if (sig == null || sig.isEmpty) {
      throw const BiometricKeyException('NATIVE', 'no signature returned');
    }
    return sig;
  }

  Future<void> revoke(String deviceId) async {
    await _invoke<bool>('revoke', <String, dynamic>{'deviceId': deviceId});
  }

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw BiometricKeyException(e.code, e.message ?? 'unknown error');
    } on MissingPluginException {
      // No native implementation registered (e.g. unit tests, web).
      throw const BiometricKeyException('UNAVAILABLE', 'platform channel not registered');
    }
  }
}

/// Failure shape thrown by [BiometricKeyService]. Codes are stable across
/// Android + iOS so callers can branch on them:
///
/// - `USER_CANCELED`  — user dismissed the prompt or hit the negative button.
/// - `LOCKOUT`        — too many failed biometric attempts; OS-level lockout.
/// - `UNAVAILABLE`    — hardware missing / not enrolled / channel not loaded.
/// - `NOT_ENROLLED`   — no keypair exists for the requested deviceId.
/// - `BIOMETRIC_ERROR`/`SIGN`/`NATIVE`/`ARG` — generic error categories.
class BiometricKeyException implements Exception {
  final String code;
  final String message;
  const BiometricKeyException(this.code, this.message);

  @override
  String toString() => 'BiometricKeyException($code): $message';
}
