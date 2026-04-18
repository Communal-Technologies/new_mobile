import 'package:equatable/equatable.dart';
import 'package:communal_mobile/data/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

/// Emitted only for [LoginRequested]. Carries a unique id so emissions are never merged with
/// Equatable like plain [AuthLoading] (all [AuthLoading] instances compare equal).
class AuthVerifyingCredentials extends AuthState {
  final int attemptId;
  const AuthVerifyingCredentials(this.attemptId);

  @override
  List<Object?> get props => [attemptId];
}

class AuthAuthenticated extends AuthState {
  final String userId;
  final String login;

  /// From [AuthRepository.getUserInfo] — used for home header, drawer, profile shortcuts.
  final UserModel user;

  /// Bumps on each successful [LoginRequested] so [Bloc.emit] is not dropped when
  /// [userId]/[login] match the prior [AppStarted] session (Equatable).
  final int sessionGeneration;

  const AuthAuthenticated({
    required this.userId,
    required this.login,
    required this.user,
    this.sessionGeneration = 0,
  });

  @override
  List<Object?> get props => [userId, login, user, sessionGeneration];
}

class AuthUnauthenticated extends AuthState {}

class AuthFailure extends AuthState {
  final String error;

  const AuthFailure(this.error);

  @override
  List<Object?> get props => [error];
}

class CheckLoginSuccess extends AuthState {
  final bool hasPassword;
  final String userId;
  final String login;
  /// Backend hint: `enter_password` | `verify_otp` (member without password).
  final String? nextStep;
  /// True when login-checker already dispatched OTP to SMS/email.
  final bool? otpSent;
  /// User-visible message when OTP could not be sent from login-checker.
  final String? otpDeliveryMessage;

  const CheckLoginSuccess({
    required this.hasPassword,
    required this.userId,
    required this.login,
    this.nextStep,
    this.otpSent,
    this.otpDeliveryMessage,
  });

  @override
  List<Object?> get props => [hasPassword, userId, login, nextStep, otpSent, otpDeliveryMessage];
}

class VerifyOtpSuccess extends AuthState {
  final String userId;
  final String contact;

  const VerifyOtpSuccess({
    required this.userId,
    required this.contact,
  });

  @override
  List<Object?> get props => [userId, contact];
}

class CreatePasswordSuccess extends AuthState {
  final String? token;

  const CreatePasswordSuccess({this.token});

  @override
  List<Object?> get props => [token];
}

class ResetPasswordSuccess extends AuthState {
  const ResetPasswordSuccess();
}