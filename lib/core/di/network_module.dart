import 'package:communal_mobile/core/constants/constants.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:communal_mobile/data/datasources/remote/dio/logging_interceptor.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/datasources/remote/dio/network_interceptor.dart';
import 'package:communal_mobile/data/datasources/remote/dio/refresh_token_interceptor.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';


@module
abstract class NetworkModule {
  @lazySingleton
  Dio dio() => Dio();

  @lazySingleton
  LoggingInterceptor loggingInterceptor() => LoggingInterceptor();

  @lazySingleton
  NetworkInterceptor networkInterceptor(ConnectivityCubit connectivityCubit) =>
      NetworkInterceptor(connectivityCubit);

  // [ServerStatusInterceptor] is intentionally NOT provided here. It's
  // wired manually in `injection.dart` after `getIt.init()` and
  // attached to the live `DioClient.dio` interceptor list. Doing it
  // that way avoids forcing a `build_runner` regeneration of
  // `injection.config.dart` for every checkout.
  @lazySingleton
  DioClient dioClient(
    Dio dio,
    LoggingInterceptor loggingInterceptor,
    NetworkInterceptor networkInterceptor,
    RefreshTokenInterceptor refreshTokenInterceptor,
  ) {
    return DioClient(
      AppConstants.baseUrl,
      loggingInterceptor: loggingInterceptor,
      networkInterceptor: networkInterceptor,
      refreshTokenInterceptor: refreshTokenInterceptor,
      customDio: dio,
    );
  }
}
