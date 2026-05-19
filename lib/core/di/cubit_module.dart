import 'package:communal_mobile/cubits/obligation_categories/obligation_categories_cubit.dart';
import 'package:communal_mobile/cubits/splash/splash_cubit.dart';
import 'package:communal_mobile/cubits/settings/settings_cubit.dart';
import 'package:communal_mobile/cubits/connectivity/connectivity_cubit.dart';
import 'package:communal_mobile/cubits/security/security_cubit.dart';
import 'package:communal_mobile/data/repositories/auth_repository.dart';
import 'package:communal_mobile/data/repositories/obligation_categories_repository.dart';
import 'package:communal_mobile/data/repositories/regions_repository.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';

@module
abstract class CubitModule {
  @lazySingleton
  SplashCubit provideSplashCubit(
    SharedPreferences prefs,
    FlutterSecureStorage secureStorage,
    DioClient dioClient,
    SettingsCubit settingsCubit,
    AuthRepository authRepository,
    RegionsRepository regionsRepository,
  ) =>
      SplashCubit(
        prefs,
        secureStorage,
        dioClient,
        settingsCubit,
        authRepository,
        regionsRepository,
      );

  @lazySingleton
  SettingsCubit get settingsCubit => SettingsCubit();

  @lazySingleton
  ConnectivityCubit get connectivityCubit => ConnectivityCubit();

  @lazySingleton
  SecurityCubit provideSecurityCubit(
    SharedPreferences prefs,
    FlutterSecureStorage secureStorage,
  ) =>
      SecurityCubit(prefs, secureStorage);

  @lazySingleton
  ObligationCategoriesCubit provideObligationCategoriesCubit(
    ObligationCategoriesRepository repository,
  ) =>
      ObligationCategoriesCubit(repository);
}
