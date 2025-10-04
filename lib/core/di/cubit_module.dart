import 'package:communal_mobile/cubits/splash/splash_cubit.dart';
import 'package:communal_mobile/cubits/settings/settings_cubit.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';

@module
abstract class CubitModule {
  @lazySingleton
  SplashCubit provideSplashCubit(
    SharedPreferences prefs,
    DioClient dioClient,
    SettingsCubit settingsCubit,
  ) =>
      SplashCubit(prefs, dioClient, settingsCubit);

  @lazySingleton
  SettingsCubit get settingsCubit => SettingsCubit();
}
