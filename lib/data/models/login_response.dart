import 'package:equatable/equatable.dart';
import 'package:communal_mobile/data/models/user_model.dart';

class LoginResponse extends Equatable {
  final String? token;
  final UserModel? user;
  final bool requiresSessionTakeoverOtp;
  final String? takeoverChallengeId;
  final String? otpChannel;
  final String? maskedDestination;
  final String? message;
  final int? otpExpiresIn;

  const LoginResponse({
    this.token,
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
        user,
        requiresSessionTakeoverOtp,
        takeoverChallengeId,
        otpChannel,
        maskedDestination,
        message,
        otpExpiresIn,
      ];
}
