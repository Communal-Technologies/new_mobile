import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import 'package:communal_mobile/core/security/biometric_key_service.dart';
import 'package:communal_mobile/core/utils/app_logger.dart';
import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';

/// Audit M38: high-level biometric-sign flow used by the transfer-verify
/// and obligation-confirm screens.
///
/// What it does (in plain terms)
/// -----------------------------
/// 1. Maintains a stable per-install `device_id` in secure storage. This
///    is the id the backend keys all biometric records on.
/// 2. Walks enrollment when needed: generates the platform keypair via
///    [BiometricKeyService], POSTs the public key to
///    `/security/biometric/enroll`. The backend's [BiometricSignatureService]
///    stores it and replays it for signature verification.
/// 3. For each sensitive operation, asks the backend for a fresh nonce
///    via `/security/biometric/challenge`, prompts the biometric to sign
///    that nonce on-device, and returns the `(deviceId, nonceId, signature)`
///    triple the gated request needs to attach via headers.
///
/// What it does NOT do
/// -------------------
/// - Not used for KYC (per product call). Only transfer + pay-obligation.
/// - Doesn't manage the welcome-back unlock biometric prompt — that's a
///   UI-gate via `local_auth` and stays unchanged. The audit M38 fix is
///   specifically about server-verifiable proof for write operations.
/// - Doesn't surface UI itself; callers handle the surrounding screens
///   and just await `signTransferIntent` / `signObligationIntent`.
@lazySingleton
class BiometricSignerService {
  BiometricSignerService(
    this._keys,
    this._secureStorage,
    this._dio,
  );

  final BiometricKeyService _keys;
  final FlutterSecureStorage _secureStorage;
  final DioClient _dio;

  static const String _kDeviceIdKey = 'biometric_device_id';
  static const String _tag = 'BiometricSigner';

  String? _deviceIdMemo;

  /// Returns this install's stable device id, generating + persisting one
  /// on first call. UUIDv4 — opaque, no PII, matches the backend `uuid`
  /// validation rule on the enroll endpoint.
  Future<String> deviceId() async {
    if (_deviceIdMemo != null) return _deviceIdMemo!;
    final stored = await _secureStorage.read(key: _kDeviceIdKey);
    if (stored != null && stored.isNotEmpty) {
      _deviceIdMemo = stored;
      return stored;
    }
    final fresh = const Uuid().v4();
    await _secureStorage.write(key: _kDeviceIdKey, value: fresh);
    _deviceIdMemo = fresh;
    return fresh;
  }

  /// Whether the device has the hardware + a usable biometric enrollment
  /// at the OS level. Doesn't check whether we've enrolled the device-key
  /// against the backend yet — see [isEnrolled] for that.
  Future<bool> isHardwareAvailable() => _keys.isAvailable();

  /// Returns true if a Keystore / Secure-Enclave key exists for this
  /// install AND the backend has the matching public key recorded.
  Future<bool> isEnrolled() async {
    try {
      final id = await deviceId();
      final localPem = await _keys.getPublicKeyPem(id);
      if (localPem == null) return false;
      final response = await _dio.get(
        ApiEndpoints.biometricStatus,
        queryParameters: <String, dynamic>{'device_id': id},
      );
      final data = response.data;
      if (data is Map && data['data'] is Map) {
        return (data['data']['enrolled'] == true);
      }
      return false;
    } catch (e) {
      AppLogger.warn(_tag, 'isEnrolled check failed: $e');
      return false;
    }
  }

  /// Generates a new Keystore / Secure-Enclave keypair AND posts the
  /// public key to the backend. Throws on either step failing.
  ///
  /// Idempotent on re-run: the native side replaces the existing key,
  /// the backend's `enroll` endpoint replaces the row in place.
  Future<void> enroll({String? deviceLabel}) async {
    final id = await deviceId();
    final pem = await _keys.generateKeyPair(id);
    final response = await _dio.post(
      ApiEndpoints.biometricEnroll,
      data: <String, dynamic>{
        'device_id': id,
        'public_key_pem': pem,
        'key_alg': 'ES256',
        if (deviceLabel != null) 'device_label': deviceLabel,
      },
    );
    final data = response.data;
    if (data is! Map || data['status'] != true) {
      throw Exception('Could not enroll device for biometric.');
    }
    AppLogger.debug(_tag, 'enroll OK device_id=$id');
  }

  /// Revokes the local key and tells the backend to mark its public-key
  /// row revoked. Used when the user disables biometric in Settings.
  Future<void> unenroll() async {
    final id = await deviceId();
    try {
      await _dio.post(
        ApiEndpoints.biometricRevoke,
        data: <String, dynamic>{'device_id': id},
      );
    } catch (e) {
      // Server-side revoke is best-effort; the local key delete is the
      // load-bearing part — without it, the user can't sign anything,
      // which gives the same outcome.
      AppLogger.warn(_tag, 'server revoke failed (continuing): $e');
    }
    await _keys.revoke(id);
  }

  /// Mints a nonce + signs it with the device's biometric-bound key.
  /// Returns the headers the caller must attach to the gated request.
  ///
  /// Caller is the transfer-verify flow.
  Future<BiometricSignedHeaders> signTransferIntent({
    String promptTitle = 'Authorize transfer',
    String promptSubtitle = 'Use biometrics to confirm this transfer',
  }) async {
    return _signIntent(
      'transfer',
      promptTitle: promptTitle,
      promptSubtitle: promptSubtitle,
    );
  }

  /// Same shape as [signTransferIntent] but for the obligation-payment flow.
  Future<BiometricSignedHeaders> signObligationIntent({
    String promptTitle = 'Authorize payment',
    String promptSubtitle = 'Use biometrics to confirm this payment',
  }) async {
    return _signIntent(
      'pay-obligation',
      promptTitle: promptTitle,
      promptSubtitle: promptSubtitle,
    );
  }

  Future<BiometricSignedHeaders> _signIntent(
    String intent, {
    required String promptTitle,
    required String promptSubtitle,
  }) async {
    final id = await deviceId();

    // 1. Mint a nonce server-side.
    final challengeResp = await _dio.post(
      ApiEndpoints.biometricChallenge,
      data: <String, dynamic>{'device_id': id, 'intent': intent},
    );
    final cdata = challengeResp.data;
    if (cdata is! Map || cdata['data'] is! Map) {
      throw Exception('Could not start biometric verification.');
    }
    final nonceId = cdata['data']['nonce_id']?.toString();
    if (nonceId == null || nonceId.isEmpty) {
      throw Exception('Biometric challenge missing nonce.');
    }

    // 2. Sign the nonce on-device. Native triggers the biometric prompt.
    final signature = await _keys.signWithBiometric(
      deviceId: id,
      payload: nonceId,
      promptTitle: promptTitle,
      promptSubtitle: promptSubtitle,
    );

    return BiometricSignedHeaders(
      deviceId: id,
      nonceId: nonceId,
      signature: signature,
    );
  }

  /// Inspects a Dio error and returns true when the failure is the backend's
  /// "this device isn't enrolled" 403 — used by callers to bounce the user
  /// to the enrollment screen instead of showing a raw error.
  static bool isNotEnrolledError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final code = data['code']?.toString();
      return code == 'device_not_enrolled';
    }
    return false;
  }
}

/// Triple the caller attaches to the next request as headers. The dio
/// extension below in this file knows how to fold these into request
/// options.
class BiometricSignedHeaders {
  final String deviceId;
  final String nonceId;
  final String signature;
  const BiometricSignedHeaders({
    required this.deviceId,
    required this.nonceId,
    required this.signature,
  });

  /// Renders to a header map matching the backend middleware's expected
  /// names (see `RequireBiometricSignature`).
  Map<String, String> toHeaders() => <String, String>{
        'X-Biometric-Device-Id': deviceId,
        'X-Biometric-Nonce-Id': nonceId,
        'X-Biometric-Signature': signature,
      };
}
