class SettingsResponse {
  final List<SettingModel> settings;

  SettingsResponse({required this.settings});

  factory SettingsResponse.fromJson(Map<String, dynamic> json) {
    final settingsList = (json['settings'] as List)
        .map((e) => SettingModel.fromJson(e))
        .toList();

    return SettingsResponse(settings: settingsList);
  }

  Map<String, dynamic> asMap() {
    // Converts settings list into Map<String, dynamic>
    return {
      for (var setting in settings) setting.key: setting.value,
    };
  }
}

class SettingModel {
  final String id;
  final String key;
  final dynamic value;

  SettingModel({required this.id, required this.key, required this.value});

  factory SettingModel.fromJson(Map<String, dynamic> json) {
    return SettingModel(id: json['id'], key: json['key'], value: json['value']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'key': key, 'value': value};
  }
}
