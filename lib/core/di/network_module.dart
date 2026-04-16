import 'package:communal_mobile/core/constants/constants.dart';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';
import 'package:communal_mobile/data/datasources/remote/dio/logging_interceptor.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/datasources/remote/dio/network_interceptor.dart';
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

  @lazySingleton
  DioClient dioClient(
    Dio dio,
    LoggingInterceptor loggingInterceptor,
    NetworkInterceptor networkInterceptor,
  ) {
    return DioClient(
      AppConstants.baseUrl,
      loggingInterceptor: loggingInterceptor,
      networkInterceptor: networkInterceptor,
      customDio: dio,
    );
  }
}
