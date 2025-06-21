import 'package:communal_mobile/core/constants/constants.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/cubits/splash/splash_cubit.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:injectable/injectable.dart';
import 'package:communal_mobile/data/datasources/remote/dio/logging_interceptor.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

@module
abstract class NetworkModule {
  @lazySingleton
  Dio dio() => Dio();

  @lazySingleton
  LoggingInterceptor loggingInterceptor() => LoggingInterceptor();

  @lazySingleton
  DioClient dioClient(
    Dio dio,
    LoggingInterceptor loggingInterceptor,
  ) {
    final baseUrl = dotenv.env['APP_ENV'] == 'development'
        ? dotenv.env['BASE_URL']!
        : AppConstants.baseUrl;

    return DioClient(
      baseUrl,
      loggingInterceptor: loggingInterceptor,
      customDio: dio,
    );
  }

  @lazySingleton
  AuthRepository provideAuthRepository(DioClient dioClient) =>
      AuthRepository(dioClient);

  @lazySingleton
  SplashCubit provideSplashCubit(SharedPreferences prefs, DioClient dioClient) =>
      SplashCubit(prefs, dioClient);

  @lazySingleton
  FlutterSecureStorage secureStorage() => const FlutterSecureStorage();

  @preResolve
  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();
}
