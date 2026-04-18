import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/data/repositories/regions_repository.dart';
import 'package:injectable/injectable.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';

@module
abstract class RepositoryModule {
  @lazySingleton
  AuthRepository provideAuthRepository(DioClient dioClient) =>
      AuthRepository(dioClient);

  @lazySingleton
  RegionsRepository provideRegionsRepository(DioClient dioClient) =>
      RegionsRepository(dioClient);
}
