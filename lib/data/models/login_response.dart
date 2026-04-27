import 'package:equatable/equatable.dart';
import 'package:communal_mobile/data/models/user_model.dart';

class LoginResponse extends Equatable {
  final String? token;

  /// Refresh token returned alongside the access token (audit M6). Required
  /// for [TokenManager] to perform proactive + reactive token refresh
  /// without re-prompting the user for credentials.
  final String? refreshToken;

  /// Access-token lifetime (seconds), as reported by `/login` and
  /// `/refresh-token`. May be null on older payload shapes; in that case
  /// the access-token's own `exp` claim is consulted instead.
  final int? expiresIn;

  final UserModel? user;
  final bool requiresSessionTakeoverOtp;
  final String? takeoverChallengeId;
  final String? otpChannel;
  final String? maskedDestination;
  final String? message;
  final int? otpExpiresIn;

  const LoginResponse({
    this.token,
    this.refreshToken,
    this.expiresIn,
    this.user,
    this.requiresSessionTakeoverOtp = false,
    this.takeoverChallengeId,
    this.otpChannel,
    this.maskedDestination,
    this.message,
    this.otpExpiresIn,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String?,
      refreshToken: json['refresh_token'] as String?,
      expiresIn: (json['expires_in'] as num?)?.toInt(),
      user: json['user'] != null
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
      requiresSessionTakeoverOtp: json['requires_session_takeover_otp'] == true,
      takeoverChallengeId: json['takeover_challenge_id'] as String?,
      otpChannel: json['otp_channel'] as String?,
      maskedDestination: json['masked_destination'] as String?,
      message: json['message'] as String?,
      otpExpiresIn: (json['otp_expires_in'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'refresh_token': refreshToken,
      'expires_in': expiresIn,
      'user': user?.toJson(),
      'requires_session_takeover_otp': requiresSessionTakeoverOtp,
      'takeover_challenge_id': takeoverChallengeId,
      'otp_channel': otpChannel,
      'masked_destination': maskedDestination,
      'message': message,
      'otp_expires_in': otpExpiresIn,
    };
  }

  @override
  List<Object?> get props => [
        token,
        refreshToken,
        expiresIn,
        user,
        requiresSessionTakeoverOtp,
        takeoverChallengeId,
        otpChannel,
        maskedDestination,
        message,
        otpExpiresIn,
      ];
}
