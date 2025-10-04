import 'package:communal_mobile/core/constants/constants.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/cubits/settings/settings_cubit.dart';
import 'package:communal_mobile/data/models/settings_model.dart';
import 'splash_state.dart';

class SplashCubit extends Cubit<SplashState> {
  final SharedPreferences prefs;
  final DioClient dioClient;
  final SettingsCubit settingsCubit;

  SplashCubit(this.prefs, this.dioClient, this.settingsCubit)
    : super(SplashInitial());

  Future<void> initApp() async {
    emit(SplashLoading());

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity == ConnectivityResult.none) {
        emit(SplashNoInternet());
        return;
      }

      final isFirstTime = prefs.getBool('first_time') ?? true;
      final token = prefs.getString('auth_token');

      final response = await dioClient.get(AppConstants.configUri);
      final settings = response.data;
      final settingsResponse = SettingsResponse.fromJson(settings);
      final settingsMap = settingsResponse.asMap();
      settingsCubit.setSettings(settingsMap);
      
      if (isFirstTime) {
        emit(SplashFirstTimeUser());
      } else if (token == null || token.isEmpty) {
        emit(SplashLoggedOut());
      } else {
        emit(SplashLoggedIn(settingsMap));
      }
    } catch (e) {
      emit(SplashError("Something went wrong: ${e.toString()}"));
    }
  }
}
