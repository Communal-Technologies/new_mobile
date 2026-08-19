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

  /// Platform-wide member self-signup switch, owned by the Communal admin.
  /// Defaults to open so a missing setting never locks registration out.
  bool get memberSignupOpen {
    final raw = state['member_allow_signup'];
    if (raw == null) return true;
    if (raw is bool) return raw;
    if (raw is num) return raw != 0;
    return const {'1', 'true', 'on', 'yes'}
        .contains(raw.toString().trim().toLowerCase());
  }
}
