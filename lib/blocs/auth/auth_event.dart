import 'package:equatable/equatable.dart';
import 'package:communal_mobile/data/models/user_model.dart';

/// Audit M37: PIN / password values appear in `props` on
/// [LoginRequested] / [CreatePasswordRequested] / [ResetPasswordRequested]
/// because Equatable uses `props` for value-equality. They must NOT
/// appear in `toString()` — `Equatable.stringify` is therefore left at
/// its default of `false` so `someEvent.toString()` returns
/// `'<EventType>()'` with no field values, even if a logger ever calls
/// `.toString()` on the event by accident. Don't enable `stringify` on
/// any event class that carries a credential.
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];

  // Do not override stringify = true — see class doc-block.
  @override
  bool? get stringify => false;
}

class AppStarted extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String login;
  final String password;

  const LoginRequested({required this.login, required this.password});

  @override
  List<Object?> get props => [login, password];
}

class LogoutRequested extends AuthEvent {}

/// Replace [AuthAuthenticated.user] after a server-side profile change (e.g. KYC tier / ledger).
class AuthUserUpdated extends AuthEvent {
  final UserModel user;

  const AuthUserUpdated(this.user);

  @override
  List<Object?> get props => [user];
}

/// Client-side cooperative switch. The cooperative_id + ledger_number are the
/// only keys requests are keyed by, so switching re-keys the in-memory
/// [UserModel] and persists the choice — no server round-trip required.
class AuthCooperativeSwitched extends AuthEvent {
  final String cooperativeId;
  final String ledgerNumber;
  final String? cooperativeName;
  final String? cooperativeLogoUrl;

  const AuthCooperativeSwitched({
    required this.cooperativeId,
    required this.ledgerNumber,
    this.cooperativeName,
    this.cooperativeLogoUrl,
  });

  @override
  List<Object?> get props =>
      [cooperativeId, ledgerNumber, cooperativeName, cooperativeLogoUrl];
}

class CheckAuthStatus extends AuthEvent {}

/// Refresh the authenticated user from the API without clearing session (silent poll).
class AuthRefreshUserRequested extends AuthEvent {}

class CheckLoginRequested extends AuthEvent {
  final String login;

  const CheckLoginRequested({required this.login});

  @override
  List<Object?> get props => [login];
}

class VerifyOtpRequested extends AuthEvent {
  final String contact;
  final String otp;
  final bool isInitialSetup;
  final String? userId;

  const VerifyOtpRequested({
    required this.contact,
    required this.otp,
    this.isInitialSetup = false,
    this.userId,
  });

  @override
  List<Object?> get props => [contact, otp, isInitialSetup, userId];
}

class CreatePasswordRequested extends AuthEvent {
  final String userId;
  final String password;
  final String confirmPassword;
  /// Email or phone used during OTP / login-checker (stored for lock screen + PIN unlock).
  final String? contact;

  const CreatePasswordRequested({
    required this.userId,
    required this.password,
    required this.confirmPassword,
    this.contact,
  });

  @override
  List<Object?> get props => [userId, password, confirmPassword, contact];
}

class ResetPasswordRequested extends AuthEvent {
  final String login;
  final String newPassword;
  final String pin;

  const ResetPasswordRequested({
    required this.login,
    required this.newPassword,
    required this.pin,
  });

  @override
  List<Object?> get props => [login, newPassword, pin];
}

class SessionTakeoverVerifyRequested extends AuthEvent {
  final String challengeId;
  final String otp;

  const SessionTakeoverVerifyRequested({
    required this.challengeId,
    required this.otp,
  });

  @override
  List<Object?> get props => [challengeId, otp];
}

class SessionTakeoverCancelled extends AuthEvent {
  const SessionTakeoverCancelled();
}