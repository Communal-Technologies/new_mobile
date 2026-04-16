import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsCubit extends Cubit<Map<String, dynamic>> {
  SettingsCubit() : super({});

  void setSettings(Map<String, dynamic> settings) {
    emit(settings);
  }

  void updateSetting(String key, dynamic value) {
    emit({...state, key: value});
  }

  dynamic get(String key) => state[key];
}
