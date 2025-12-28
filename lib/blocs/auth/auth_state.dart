import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final String userId;
  final String login;

  const AuthAuthenticated({required this.userId, required this.login});

  @override
  List<Object?> get props => [userId, login];
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

  const CheckLoginSuccess({
    required this.hasPassword,
    required this.userId,
    required this.login,
  });

  @override
  List<Object?> get props => [hasPassword, userId, login];
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