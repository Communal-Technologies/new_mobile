import 'dart:typed_data';

import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:dio/dio.dart';

class KycRepository {
  KycRepository(this._dioClient);

  final DioClient _dioClient;

  /// Step 1: create Anchor customer + persist profile. Returns Anchor `anchor_customer_id`.
  /// [userId] is kept for caller compatibility but is not sent in the URL —
  /// kycsvc reads the user ID from the JWT `sub` claim.
  Future<String> registerProfile({
    required String userId,
    required Map<String, dynamic> body,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.kycCreate,
        data: body,
        idempotencyKey: idempotencyKey,
      );
      final data = response.data;
      if (data is Map && (data['success'] == true || data['success'] == 'true')) {
        final inner = data['data'];
        final id = (inner is Map ? inner['anchor_customer_id'] : null)?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
      throw Exception(
        data is Map
            ? (data['message']?.toString() ?? 'Registration failed')
            : 'Registration failed',
      );
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Step 1 again, for a customer that already exists: edits the Anchor
  /// customer instead of creating one. Returns 204 with no body.
  Future<void> updateProfile({
    required String anchorCustomerId,
    required Map<String, dynamic> body,
    String? idempotencyKey,
  }) async {
    try {
      await _dioClient.patch(
        ApiEndpoints.kycUpdateCustomer(anchorCustomerId),
        data: body,
        idempotencyKey: idempotencyKey,
      );
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Step 2 (BVN): submits BVN to Anchor for tier-1 verification.
  /// Returns the `data` payload on success (contains `message`).
  Future<Map<String, dynamic>?> upgradeToTier1({
    required String anchorCustomerId,
    required String bvn,
    required String dateOfBirth,
    required String gender,
    String? idempotencyKey,
  }) async {
    try {
      final response = await _dioClient.post(
        ApiEndpoints.kycUpgradeTier1(anchorCustomerId),
        data: <String, dynamic>{
          'bvn': bvn,
          'date_of_birth': dateOfBirth,
          'gender': gender,
        },
        idempotencyKey: idempotencyKey,
      );
      final data = response.data;
      if (data is Map && (data['success'] == true || data['success'] == 'true')) {
        final inner = data['data'];
        if (inner is Map) {
          return Map<String, dynamic>.from(inner);
        }
        return null;
      }
      throw Exception(
        data is Map
            ? (data['message']?.toString() ?? 'BVN verification failed')
            : 'BVN verification failed',
      );
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Step 3 (Communal tier_2 / Anchor `TIER_3` identity): multipart front/back files + fields.
  /// Use bytes only when file paths are unavailable.
  Future<Map<String, dynamic>?> upgradeToTier2({
    required String anchorCustomerId,
    required String idNumber,
    required String idType,
    String? expiryDateYmd,
    String? fileFrontPath,
    Uint8List? fileFrontBytes,
    required String fileFrontName,
    String? fileBackPath,
    Uint8List? fileBackBytes,
    String? fileBackName,
    String? idempotencyKey,
  }) async {
    try {
      final MultipartFile frontMultipart;
      final MultipartFile legacyFrontMultipart;
      if (fileFrontPath != null && fileFrontPath.trim().isNotEmpty) {
        final safeFrontPath = fileFrontPath.trim();
        frontMultipart = await MultipartFile.fromFile(
          safeFrontPath,
          filename: fileFrontName,
        );
        // Must be a separate instance; MultipartFile is single-use once finalized.
        legacyFrontMultipart = await MultipartFile.fromFile(
          safeFrontPath,
          filename: fileFrontName,
        );
      } else if (fileFrontBytes != null && fileFrontBytes.isNotEmpty) {
        frontMultipart = MultipartFile.fromBytes(
          fileFrontBytes,
          filename: fileFrontName,
        );
        legacyFrontMultipart = MultipartFile.fromBytes(
          fileFrontBytes,
          filename: fileFrontName,
        );
      } else {
        throw Exception('No front document selected.');
      }

      final map = <String, dynamic>{
        // Send both legacy (`file`) and explicit (`file_front`) for compatibility.
        'file': legacyFrontMultipart,
        'file_front': frontMultipart,
        'id_number': idNumber,
        'id_type': idType,
      };
      final hasBackPath =
          fileBackPath != null && fileBackPath.trim().isNotEmpty;
      final hasBackBytes = fileBackBytes != null && fileBackBytes.isNotEmpty;
      if (hasBackPath || hasBackBytes) {
        final safeBackPath = fileBackPath?.trim();
        final backMultipart = hasBackPath
            ? await MultipartFile.fromFile(
                safeBackPath!,
                filename: (fileBackName != null && fileBackName.isNotEmpty)
                    ? fileBackName
                    : 'id_back.jpg',
              )
            : MultipartFile.fromBytes(
                fileBackBytes!,
                filename: (fileBackName != null && fileBackName.isNotEmpty)
                    ? fileBackName
                    : 'id_back.jpg',
              );
        map['file_back'] = backMultipart;
      }
      final exp = expiryDateYmd?.trim();
      if (exp != null && exp.isNotEmpty) {
        map['expiry_date'] = exp;
      }

      final formData = FormData.fromMap(map);
      final response = await _dioClient.postFormData(
        ApiEndpoints.kycUpgradeTier2(anchorCustomerId),
        data: formData,
        idempotencyKey: idempotencyKey,
      );
      final data = response.data;
      if (data is Map && (data['success'] == true || data['success'] == 'true')) {
        final inner = data['data'];
        if (inner is Map) {
          return Map<String, dynamic>.from(inner);
        }
        return null;
      }
      throw Exception(
        data is Map
            ? (data['message']?.toString() ?? 'Identity verification failed')
            : 'Identity verification failed',
      );
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Records whether the user agreed to share identity data with Anchor for KYC.
  /// [decision] must be either `'agreed'` or `'declined'`.
  Future<void> recordConsent({
    required String anchorCustomerId,
    required String decision,
    String consentVersion = 'anchor_kyc_v1',
  }) async {
    try {
      await _dioClient.post(
        ApiEndpoints.kycRecordConsent,
        data: <String, dynamic>{
          'anchor_customer_id': anchorCustomerId,
          'decision': decision,
          'consent_version': consentVersion,
        },
      );
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  String _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
      final errors = data['errors'];
      if (errors is Map) {
        final parts = <String>[];
        for (final entry in errors.entries) {
          final v = entry.value;
          if (v is List && v.isNotEmpty) {
            parts.add(v.first.toString());
          } else if (v != null) {
            parts.add(v.toString());
          }
        }
        if (parts.isNotEmpty) return parts.join(' ');
      }
    }
    return e.message ?? 'Request failed';
  }
}
