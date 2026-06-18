// auth_repository.dart
import 'package:communal_mobile/data/datasources/remote/api_endpoints.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/data/models/login_response.dart';
import 'package:communal_mobile/core/utils/app_logger.dart';
import 'package:dio/dio.dart';

/// Thrown by [AuthRepository.requestOtpForSignup] when the backend
/// reports that an account already exists for the given contact (HTTP
/// 409 with `error_code: 'account_exists'`). The signup screen catches
/// this and routes the user to the login screen instead of pushing
/// forward into the OTP step.
class AccountAlreadyExistsException implements Exception {
  AccountAlreadyExistsException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthRepository {
  static const String _tag = 'AuthRepository';

  final DioClient dioClient;
  static const String _platform = 'mobile_app'; // Platform identifier for mobile app

  AuthRepository(this.dioClient);

  /// Update the token in DioClient for authenticated requests
  void updateToken(String token) {
    dioClient.updateToken(token);
  }

  Future<LoginResponse?> login(String login, String password) async {
    try {
      // This endpoint doesn't require authentication (public login endpoint)
      final response = await dioClient.post(
        ApiEndpoints.login,
        data: {
          'login': login,
          'password': password,
          'platform': _platform, // Required by backend to identify platform type
        },
        requireAuth: false, // No auth required for login
      );

      if (response.statusCode == 200) {
        return LoginResponse.fromJson(response.data);
      }
    } on DioException catch (e) {
      // Extract error message from response
      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        String errorMessage = 'Login failed. Please check your credentials.';
        
        // Handle rate limiting and account lockout (429 Too Many Requests)
        if (statusCode == 429) {
          if (responseData is Map) {
            final message = responseData['message']?.toString().toLowerCase() ?? '';
            
            // Check if it's an account lockout (from our custom security service)
            if (message.contains('locked') || message.contains('lockout')) {
              final lockedUntil = responseData['locked_until'];
              final minutesRemaining = responseData['minutes_remaining'];
              
              if (minutesRemaining != null) {
                final minutes = int.tryParse(minutesRemaining.toString()) ?? 30;
                errorMessage = 'Account temporarily locked due to multiple failed attempts. Please try again in $minutes minute${minutes > 1 ? 's' : ''}.';
              } else if (lockedUntil != null) {
                errorMessage = 'Account temporarily locked. Please try again later.';
              } else {
                errorMessage = responseData['message'] ?? 'Account temporarily locked. Please try again later.';
              }
            } else {
              // It's a rate limit from Laravel's throttle middleware
              // Check for retry-after header or provide default message
              final retryAfter = e.response?.headers.value('retry-after');
              
              if (retryAfter != null) {
                final seconds = int.tryParse(retryAfter) ?? 60;
                final minutes = (seconds / 60).ceil();
                errorMessage = 'Too many login attempts. Please wait $minutes minute${minutes > 1 ? 's' : ''} before trying again.';
              } else {
                errorMessage = responseData['message'] ?? 'Too many login attempts. Please wait a few minutes before trying again.';
              }
            }
          } else if (responseData is String) {
            final message = responseData.toLowerCase();
            if (message.contains('too many') || message.contains('throttle')) {
              errorMessage = 'Too many login attempts. Please wait a few minutes before trying again.';
            } else if (message.contains('locked') || message.contains('lockout')) {
              errorMessage = 'Account temporarily locked. Please try again later.';
            } else {
              errorMessage = responseData;
            }
          } else {
            errorMessage = 'Too many login attempts. Please wait a few minutes before trying again.';
          }
          throw Exception(errorMessage);
        }
        
        // Handle other errors
        if (responseData is Map) {
          errorMessage = responseData['message'] ?? 
                        responseData['error'] ?? 
                        (responseData['errors'] != null 
                          ? responseData['errors'].toString() 
                          : errorMessage);
        } else if (responseData is String) {
          errorMessage = responseData;
        }
        
        throw Exception(errorMessage);
      } else {
        throw Exception('Network error. Please check your connection.');
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  /// Completes login after OTP when another device still had an active session.
  Future<LoginResponse?> verifySessionTakeover(
    String takeoverChallengeId,
    String otp,
  ) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.sessionTakeoverVerify,
        data: {
          'takeover_challenge_id': takeoverChallengeId,
          'otp': otp,
        },
        requireAuth: false,
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        return LoginResponse.fromJson(response.data as Map<String, dynamic>);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final responseData = e.response?.data;
        String errorMessage = 'Invalid or expired code.';
        if (responseData is Map) {
          errorMessage = responseData['message']?.toString() ?? errorMessage;
        } else if (responseData is String) {
          errorMessage = responseData;
        }
        throw Exception(errorMessage);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<void> resendSessionTakeoverOtp(String takeoverChallengeId) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.sessionTakeoverResendOtp,
        data: {'takeover_challenge_id': takeoverChallengeId},
        requireAuth: false,
      );
      if (response.statusCode != 200) {
        throw Exception('Unable to resend code');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final responseData = e.response?.data;
        final msg = responseData is Map
            ? (responseData['message']?.toString() ?? 'Unable to resend code')
            : 'Unable to resend code';
        throw Exception(msg);
      }
      rethrow;
    }
  }

  Future<UserModel?> getUserInfo(String token) async {
    // Ensure token is set in DioClient before making the request.
    updateToken(token);
    try {
      final response = await dioClient.get(ApiEndpoints.getLoggedInUser);
      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data);
      }
    } on DioException catch (e) {
      AppLogger.warn(
        _tag,
        'getUserInfo failed (status=${e.response?.statusCode}, type=${e.type.name})',
      );
      rethrow;
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'getUserInfo unexpected error',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
    return null;
  }

  Future<void> updateDeviceToken(String deviceToken) async {
    final token = deviceToken.trim();
    if (token.isEmpty) return;
    await dioClient.post(
      ApiEndpoints.profileDeviceToken,
      data: {'device_token': token},
    );
  }

  /// Verify password/PIN for an already-authenticated session unlock.
  /// This avoids calling `/login` again (which can trigger session takeover OTP).
  ///
  /// Audit M7: parses the backend's 429 + Retry-After response (the
  /// `/security/transaction/verify-password` route is rate-limited at 5
  /// attempts per 5 minutes per user) and throws a friendly countdown
  /// message so the welcome-back screen can render "Try again in N
  /// minutes" rather than a vague "Too Many Requests".
  Future<bool> verifySessionUnlockPassword(String password) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.securityVerifyPassword,
        data: {'password': password},
      );

      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        return data['verified'] == true;
      }

      return false;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        // Rate-limited: surface a countdown so the user knows when to retry.
        final retryAfter = e.response?.headers.value('retry-after');
        final seconds = int.tryParse(retryAfter ?? '') ?? 300;
        throw Exception(_friendlyRetryAfter(seconds));
      }
      if (e.response != null) {
        final responseData = e.response?.data;
        String errorMessage = 'Unable to verify PIN';
        if (responseData is Map) {
          errorMessage = responseData['message']?.toString() ?? errorMessage;
        } else if (responseData is String) {
          errorMessage = responseData;
        }
        throw Exception(errorMessage);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Renders a [Retry-After] seconds value as a user-facing countdown.
  /// "Try again in 1 minute" / "Try again in 5 minutes" / "Try again in
  /// 30 seconds".
  String _friendlyRetryAfter(int seconds) {
    if (seconds < 60) {
      return 'Too many PIN attempts. Try again in $seconds seconds.';
    }
    final minutes = (seconds / 60).ceil();
    return 'Too many PIN attempts. Try again in $minutes '
        'minute${minutes > 1 ? 's' : ''}.';
  }

  Future<Map<String, dynamic>?> checkLogin(String login) async {
    try {
      // This endpoint doesn't require authentication
      final response = await dioClient.post(
        ApiEndpoints.loginChecker,
        data: {'login': login, 'user': 'member'},
        requireAuth: false, // No auth required for login check
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data;
        String? nextStep;
        bool? otpSent;
        String? otpDeliveryMessage;
        if (data is Map<String, dynamic>) {
          nextStep = data['next_step']?.toString();
          final od = data['otp_delivery'];
          if (data['password'] != 1 && od is Map) {
            otpSent = od['sent'] == true;
            if (od['sent'] != true && od['message'] != null) {
              otpDeliveryMessage = od['message'].toString();
            }
          }
        }
        return {
          'hasPassword': response.data['password'] == 1,
          'userId': response.data['login']['id'].toString(),
          'login': login,
          'nextStep': nextStep,
          'otpSent': otpSent,
          'otpDeliveryMessage': otpDeliveryMessage,
        };
      }
    } on DioException catch (e) {
      // Extract error message from response
      if (e.response != null) {
        final errorMessage = e.response?.data['message'] ?? 
                           e.response?.data['error'] ?? 
                           'User not found';
        throw Exception(errorMessage);
      } else {
        throw Exception('Network error. Please check your connection.');
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  /// Verifies OTP. [contact] is the same login string as check-login (email or E.164 phone);
  /// the backend picks SMS vs email from the credential shape. [purpose]
  /// stays `verification` for password reset / login OTP and is `signup`
  /// for the self-signup flow — backend mints `user_id` on the response
  /// only for `signup` so the next screen can call /create-account-password.
  Future<bool> verifyOtp(
    String contact,
    String otp, {
    String purpose = 'verification',
  }) async {
    try {
      final body = <String, dynamic>{
        'login': contact.trim(),
        'otp': otp,
        'purpose': purpose,
      };

      final response = await dioClient.post(
        ApiEndpoints.otpVerify,
        data: body,
        requireAuth: false,
      );

      if (response.statusCode == 200 && response.data is Map) {
        final map = response.data as Map<String, dynamic>;
        return map['success'] == true;
      }
      return false;
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        final msg = data is Map
            ? (data['message']?.toString() ?? 'Invalid or expired code')
            : 'Invalid or expired code';
        throw Exception(msg);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Verify OTP for the self-signup flow. Returns `(success, userId)` —
  /// backend assigns / resolves the user id on first OTP verify with
  /// `purpose=signup` and surfaces it in the response so we can carry it
  /// forward to /create-account-password.
  Future<({bool success, String? userId})> verifyOtpForSignup(
    String contact,
    String otp,
  ) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.otpVerify,
        data: <String, dynamic>{
          'login': contact.trim(),
          'otp': otp,
          'purpose': 'signup',
        },
        requireAuth: false,
      );

      if (response.statusCode == 200 && response.data is Map) {
        final map = response.data as Map<String, dynamic>;
        final ok = map['success'] == true;
        final data = map['data'];
        final userId = data is Map ? data['user_id']?.toString() : null;
        return (success: ok, userId: userId);
      }
      return (success: false, userId: null);
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        final msg = data is Map
            ? (data['message']?.toString() ?? 'Invalid or expired code')
            : 'Invalid or expired code';
        throw Exception(msg);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Request OTP: backend resolves **SMS** vs **email** from [contact] and calls **notificationsvc**
  /// (`/notifications/sms` or `/notifications/email/otp`) when enabled.
  /// Pass `purpose: 'signup'` for the self-signup flow — backend will
  /// upsert a User row for the contact and surface its id in the
  /// response (consumed via [requestOtpForSignup]).
  Future<bool> requestOtp(
    String contact, {
    String purpose = 'verification',
    String deliveryMethod = 'auto',
  }) async {
    try {
      final body = <String, dynamic>{
        'login': contact.trim(),
        'purpose': purpose,
        'delivery_method': deliveryMethod,
      };

      final response = await dioClient.post(
        ApiEndpoints.otpSend,
        data: body,
        requireAuth: false,
      );

      if (response.statusCode == 200 && response.data is Map) {
        final map = response.data as Map<String, dynamic>;
        return map['success'] == true;
      }
      return false;
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        final msg = data is Map
            ? (data['message']?.toString() ?? 'Unable to send verification code')
            : 'Unable to send verification code';
        throw Exception(msg);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Self-signup OTP send. Returns the userId the backend created or
  /// resumed for this contact, so we can carry it through the rest of
  /// the signup chain. Returns null when the send failed but didn't
  /// throw (rare — the request layer normally throws on non-200).
  Future<String?> requestOtpForSignup(
    String contact, {
    String deliveryMethod = 'auto',
  }) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.otpSend,
        data: <String, dynamic>{
          'login': contact.trim(),
          'purpose': 'signup',
          'delivery_method': deliveryMethod,
        },
        requireAuth: false,
      );

      if (response.statusCode == 200 && response.data is Map) {
        final map = response.data as Map<String, dynamic>;
        if (map['success'] != true) return null;
        final data = map['data'];
        return data is Map ? data['user_id']?.toString() : null;
      }
      return null;
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        if (e.response?.statusCode == 409 &&
            data is Map &&
            data['error_code']?.toString() == 'account_exists') {
          throw AccountAlreadyExistsException(
            data['message']?.toString() ??
                'An account already exists for this contact. Please log in instead.',
          );
        }
        final msg = data is Map
            ? (data['message']?.toString() ?? 'Unable to send verification code')
            : 'Unable to send verification code';
        throw Exception(msg);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  /// Poll OTP delivery diagnostics (queued/sent/failed + fallback note).
  Future<Map<String, dynamic>?> getOtpDeliveryStatus(
    String contact, {
    String purpose = 'verification',
  }) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.otpDeliveryStatus,
        data: <String, dynamic>{
          'login': contact.trim(),
          'purpose': purpose,
        },
        requireAuth: false,
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final map = response.data as Map<String, dynamic>;
        final data = map['data'];
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
      return null;
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        final msg = data is Map
            ? (data['message']?.toString() ?? 'Unable to fetch OTP delivery status')
            : 'Unable to fetch OTP delivery status';
        throw Exception(msg);
      }
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<LoginResponse?> createPassword(String userId, String password) async {
    try {
      // This endpoint doesn't require authentication (user doesn't have password yet)
      final response = await dioClient.post(
        ApiEndpoints.createAccountPassword,
        data: {
          'user': userId,
          'password': password,
          'new_password': password,
          'platform': 'mobile_app',
        },
        requireAuth: false,
      );

      if (response.statusCode != 200) return null;
      if (response.data is! Map) return null;

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['token'] == null) {
        // No token returned — caller will fall back to a separate login.
        return null;
      }

      UserModel? user;
      if (responseData['user'] is Map) {
        try {
          user = UserModel.fromJson(
            responseData['user'] as Map<String, dynamic>,
          );
        } catch (userParseError, stackTrace) {
          AppLogger.warn(_tag, 'createPassword: user parse failed',
              error: userParseError);
          AppLogger.debug(_tag, 'stack', stackTrace: stackTrace);
        }
      }

      return LoginResponse(
        token: responseData['token'] as String?,
        user: user,
      );
    } on DioException catch (e) {
      AppLogger.warn(
        _tag,
        'createPassword failed (status=${e.response?.statusCode}, type=${e.type.name})',
      );
      if (e.response != null) {
        final responseData = e.response?.data;
        String errorMessage = 'Failed to create password';
        if (responseData is Map) {
          errorMessage = responseData['message'] ??
              responseData['error'] ??
              (responseData['errors'] != null
                  ? responseData['errors'].toString()
                  : errorMessage);
        } else if (responseData is String) {
          errorMessage = responseData;
        }
        throw Exception(errorMessage);
      }
      throw Exception('Network error. Please check your connection.');
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'createPassword unexpected error',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> requestPasswordReset(String login) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.generatePasswordResetLink,
        data: {'login': login},
        requireAuth: false,
      );
      if (response.statusCode != 200) {
        throw Exception('Unable to send reset code');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        final msg = data is Map
            ? (data['message']?.toString() ?? 'Unable to send reset code')
            : 'Unable to send reset code';
        throw Exception(msg);
      }
      rethrow;
    }
  }

  Future<void> verifyPasswordResetPin(String login, String pin) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.verifyPasswordResetPin,
        data: {'login': login, 'pin': pin},
        requireAuth: false,
      );
      if (response.statusCode != 200) {
        throw Exception('Invalid verification code');
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response?.data;
        final msg = data is Map
            ? (data['message']?.toString() ?? 'Invalid verification code')
            : 'Invalid verification code';
        throw Exception(msg);
      }
      rethrow;
    }
  }

  Future<bool> resetPassword(String login, String newPassword, String pin) async {
    try {
      // Note: Backend uses PUT method.
      final response = await dioClient.put(
        ApiEndpoints.resetPassword,
        data: {
          'login': login,
          'pin': pin,
          'new_password': newPassword,
          'platform': _platform,
        },
        requireAuth: false,
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        return false;
      }

      final responseData = response.data;
      if (responseData is Map) {
        final message =
            responseData['message']?.toString().toLowerCase() ?? '';
        if (message.contains('success') ||
            message.contains('updated') ||
            responseData['status'] == true ||
            responseData['message'] != null) {
          return true;
        }
        return false;
      }
      return true;
    } on DioException catch (e) {
      AppLogger.warn(
        _tag,
        'resetPassword failed (status=${e.response?.statusCode}, type=${e.type.name})',
      );
      if (e.response != null) {
        final responseData = e.response?.data;
        String errorMessage = 'Unable to reset password. Please try again.';
        if (responseData is Map) {
          errorMessage = responseData['message'] ??
              responseData['error'] ??
              (responseData['errors'] != null
                  ? responseData['errors'].toString()
                  : errorMessage);
        } else if (responseData is String) {
          errorMessage = responseData;
        }
        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e, stackTrace) {
      AppLogger.error(_tag, 'resetPassword unexpected error',
          error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// `GET /auth/login-activity` — returns the last 50 auth audit log entries.
  Future<List<Map<String, dynamic>>> fetchLoginActivity() async {
    try {
      final response = await dioClient.get(ApiEndpoints.memberLoginActivity);
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['logs'] is List) {
          return (data['logs'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }
      return [];
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message']?.toString();
        if (msg != null && msg.isNotEmpty) throw Exception(msg);
      }
      throw Exception(e.message ?? 'Failed to load activity');
    }
  }

  /// `POST /members/change-password` — changes the login PIN/password.
  /// Throws an [Exception] with a user-facing message on failure.
  Future<void> changeLoginPin(String oldPin, String newPin) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.membersChangePassword,
        data: <String, dynamic>{
          'old_password': oldPin,
          'new_password': newPin,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) return;
      final data = response.data;
      if (data is Map) {
        final msg = data['message']?.toString();
        if (msg != null && msg.isNotEmpty) throw Exception(msg);
      }
      throw Exception('PIN change failed');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        // 422 responses carry an `errors` map with field-level messages.
        // Prefer that over the generic "The given data was invalid." message.
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) {
            throw Exception(first.first.toString());
          }
        }
        final msg = data['message']?.toString();
        if (msg != null && msg.isNotEmpty) throw Exception(msg);
      }
      throw Exception(e.message ?? 'PIN change failed');
    }
  }

  /// `POST /members/account/request-unfreeze` with `{ reason }` (min 10 chars).
  Future<void> requestAccountUnfreeze(String reason) async {
    try {
      final response = await dioClient.post(
        ApiEndpoints.membersRequestUnfreeze,
        data: <String, dynamic>{'reason': reason},
      );
      final data = response.data;
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data is Map &&
            (data['status'] == true || data['status'] == 'true')) {
          return;
        }
        if (data is Map) {
          final msg = data['message']?.toString();
          if (msg != null && msg.isNotEmpty) throw Exception(msg);
        }
        return;
      }
      throw Exception('Request failed');
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message']?.toString();
        if (msg != null && msg.isNotEmpty) throw Exception(msg);
      }
      throw Exception(e.message ?? 'Request failed');
    }
  }
}
