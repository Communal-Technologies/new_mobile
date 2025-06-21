import 'package:communal_mobile/blocs/auth/auth_event.dart';
import 'package:communal_mobile/blocs/auth/auth_state.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@injectable
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;
  final FlutterSecureStorage secureStorage;

  AuthBloc({required this.authRepository, required this.secureStorage})
    : super(AuthInitial()) {
    on<AppStarted>(_onAppStarted);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<CheckAuthStatus>(_onCheckAuthStatus);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());

    final token = await secureStorage.read(key: 'token');

    if (token != null) {
      final user = await authRepository.getUserInfo(token);
      if (user != null) {
        emit(AuthAuthenticated(userId: user.id, login: user.login));
      } else {
        emit(AuthUnauthenticated());
      }
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final loginResponse = await authRepository.login(
        event.login,
        event.password,
      );

      if (loginResponse != null) {
        await secureStorage.write(key: 'token', value: loginResponse.token);

        final user = await authRepository.getUserInfo(loginResponse.token);

        if (user != null) {
          emit(AuthAuthenticated(userId: user.id, login: user.login));
        } else {
          emit(AuthUnauthenticated());
        }
      } else {
        emit(const AuthFailure("Invalid login response"));
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await secureStorage.delete(key: 'token');
    emit(AuthUnauthenticated());
  }

  Future<void> _onCheckAuthStatus(
    CheckAuthStatus event,
    Emitter<AuthState> emit,
  ) async {
    final token = await secureStorage.read(key: 'token');

    if (token != null) {
      final user = await authRepository.getUserInfo(token);
      if (user != null) {
        emit(AuthAuthenticated(userId: user.id, login: user.login));
      } else {
        emit(AuthUnauthenticated());
      }
    } else {
      emit(AuthUnauthenticated());
    }
  }
}
