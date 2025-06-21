// splash_state.dart
abstract class SplashState {}

class SplashInitial extends SplashState {}

class SplashLoading extends SplashState {}

class SplashNoInternet extends SplashState {}

class SplashFirstTimeUser extends SplashState {}

class SplashLoggedOut extends SplashState {}

class SplashLoggedIn extends SplashState {}

class SplashError extends SplashState {
  final String message;
  SplashError(this.message);
}
