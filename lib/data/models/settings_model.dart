class SettingsResponse {
  final List<SettingModel> settings;

  SettingsResponse({required this.settings});

  factory SettingsResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['settings'];
    if (raw is! List) return SettingsResponse(settings: const []);

    final settingsList = <SettingModel>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final model = SettingModel.fromJson(Map<String, dynamic>.from(entry));
      if (model.key.isEmpty) continue;
      settingsList.add(model);
    }

    return SettingsResponse(settings: settingsList);
  }

  Map<String, dynamic> asMap() {
    return {
      for (var setting in settings) setting.key: setting.value,
    };
  }
}

class SettingModel {
  final String? id;
  final String key;
  final dynamic value;

  SettingModel({this.id, required this.key, required this.value});

  factory SettingModel.fromJson(Map<String, dynamic> json) {
    return SettingModel(
      id: json['id']?.toString(),
      key: json['key']?.toString() ?? '',
      value: json['value'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'key': key,
      'value': value,
    };
  }
}
