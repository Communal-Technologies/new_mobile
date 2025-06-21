// dart format width=80
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:communal_mobile/blocs/auth/auth_bloc.dart' as _i789;
import 'package:communal_mobile/core/di/network_module.dart' as _i770;
import 'package:communal_mobile/cubits/splash/splash_cubit.dart' as _i739;
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart'
    as _i750;
import 'package:communal_mobile/data/datasources/remote/dio/logging_interceptor.dart'
    as _i354;
import 'package:communal_mobile/data/repositories/auth_repository.dart'
    as _i493;
import 'package:dio/dio.dart' as _i361;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

extension GetItInjectableX on _i174.GetIt {
  // initializes the registration of main-scope dependencies inside of GetIt
  Future<_i174.GetIt> init({
    String? environment,
    _i526.EnvironmentFilter? environmentFilter,
  }) async {
    final gh = _i526.GetItHelper(this, environment, environmentFilter);
    final networkModule = _$NetworkModule();
    await gh.factoryAsync<_i460.SharedPreferences>(
      () => networkModule.prefs(),
      preResolve: true,
    );
    gh.lazySingleton<_i361.Dio>(() => networkModule.dio());
    gh.lazySingleton<_i354.LoggingInterceptor>(
      () => networkModule.loggingInterceptor(),
    );
    gh.lazySingleton<_i558.FlutterSecureStorage>(
      () => networkModule.secureStorage(),
    );
    gh.lazySingleton<_i750.DioClient>(
      () => networkModule.dioClient(
        gh<_i361.Dio>(),
        gh<_i354.LoggingInterceptor>(),
      ),
    );
    gh.lazySingleton<_i739.SplashCubit>(
      () => networkModule.provideSplashCubit(
        gh<_i460.SharedPreferences>(),
        gh<_i750.DioClient>(),
      ),
    );
    gh.lazySingleton<_i493.AuthRepository>(
      () => networkModule.provideAuthRepository(gh<_i750.DioClient>()),
    );
    gh.factory<_i789.AuthBloc>(
      () => _i789.AuthBloc(
        authRepository: gh<_i493.AuthRepository>(),
        secureStorage: gh<_i558.FlutterSecureStorage>(),
      ),
    );
    return this;
  }
}

class _$NetworkModule extends _i770.NetworkModule {}
