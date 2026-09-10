import 'package:communal_mobile/core/services/otp_session_storage.dart';

abstract class SplashState {}

class SplashInitial extends SplashState {}

class SplashLoading extends SplashState {}

class SplashNoInternet extends SplashState {}

class SplashFirstTimeUser extends SplashState {}

class SplashLoggedOut extends SplashState {}

class SplashLoggedIn extends SplashState {
  final Map<String, dynamic> settingsMap;
  SplashLoggedIn(this.settingsMap);
}

/// A signup OTP verification was left in progress (app closed before the
/// user confirmed the code). Carries the persisted session so the screen
/// can be resumed with the right contact/method/userId.
class SplashPendingOtpVerification extends SplashState {
  final PendingOtpSession session;
  SplashPendingOtpVerification(this.session);
}

class SplashError extends SplashState {
  final String message;
  SplashError(this.message);
}