import 'dart:io';

import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/member_profile_details.dart';
import 'package:dio/dio.dart';

class ProfileUpdateResult {
  ProfileUpdateResult({this.anchorWarning});

  /// Set when the local DB update succeeded but Anchor sync failed.
  /// Show a non-blocking warning to the user — their local view is
  /// up-to-date but Anchor is stale until the next sync.
  final String? anchorWarning;
}

class ProfileRepository {
  ProfileRepository(this._dioClient);

  final DioClient _dioClient;

  /// Fetch full profile (first/middle/last name, address, dob, etc.)
  /// for the my-profile / edit-profile screens. Accepts the user_id
  /// (UUID); the backend resolves to the profile row.
  Future<MemberProfileDetails> fetchMyProfile(String userId) async {
    try {
      final response = await _dioClient.get(
        ApiEndpoints.membersFetchUserDetails(userId),
      );
      final body = response.data;
      if (body is Map && body['profile'] is Map) {
        return MemberProfileDetails.fromJson(
          Map<String, dynamic>.from(body['profile'] as Map),
        );
      }
      throw Exception('Unexpected response from server.');
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Patch a delta. Backend mirrors only the keys provided to Anchor's
  /// `PATCH /customers/{id}`, so per-field saves are cheap and safe.
  Future<ProfileUpdateResult> updateMyProfile(Map<String, dynamic> changes) async {
    try {
      final response = await _dioClient.put(
        ApiEndpoints.membersUpdateProfile,
        data: changes,
      );
      final body = response.data;
      String? anchorWarning;
      if (body is Map) {
        final w = body['anchor_warning'];
        if (w is String && w.isNotEmpty) anchorWarning = w;
      }
      return ProfileUpdateResult(anchorWarning: anchorWarning);
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  /// Upload + replace the user's avatar. Backend writes the file to
  /// secure storage and returns a temporarily-signed URL the client
  /// can render until the next refresh.
  Future<String> uploadAvatar(File file) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(file.path, filename: fileName),
      });
      final response = await _dioClient.postFormData(
        ApiEndpoints.membersUploadAvatar,
        data: formData,
      );
      final body = response.data;
      if (body is Map && body['avatar'] is String) {
        return body['avatar'] as String;
      }
      throw Exception('Unexpected response from server.');
    } on DioException catch (e) {
      throw Exception(_messageFromDio(e));
    }
  }

  String _messageFromDio(DioException e) {
    final response = e.response;
    if (response == null) return 'Network error. Please check your connection.';
    final data = response.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is String && msg.isNotEmpty) return msg;
    }
    return 'Unable to update profile.';
  }
}
