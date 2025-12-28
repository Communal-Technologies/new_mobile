import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
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

class CheckAuthStatus extends AuthEvent {}

class CheckLoginRequested extends AuthEvent {
  final String login;

  const CheckLoginRequested({required this.login});

  @override
  List<Object?> get props => [login];
}

class VerifyOtpRequested extends AuthEvent {
  final String contact;
  final String otp;
  final bool isEmail;
  final bool isInitialSetup;
  final String? userId;

  const VerifyOtpRequested({
    required this.contact,
    required this.otp,
    this.isEmail = true,
    this.isInitialSetup = false,
    this.userId,
  });

  @override
  List<Object?> get props => [contact, otp, isEmail, isInitialSetup, userId];
}

class CreatePasswordRequested extends AuthEvent {
  final String userId;
  final String password;
  final String confirmPassword;

  const CreatePasswordRequested({
    required this.userId,
    required this.password,
    required this.confirmPassword,
  });

  @override
  List<Object?> get props => [userId, password, confirmPassword];
}

class ResetPasswordRequested extends AuthEvent {
  final String login;
  final String newPassword;

  const ResetPasswordRequested({
    required this.login,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [login, newPassword];
}