import 'package:equatable/equatable.dart';

/// Active cooperative region from `GET /fetch-regions`.
class RegionModel extends Equatable {
  /// Used until `fetch-regions` succeeds or when the request fails.
  static const List<RegionModel> offlineFallback = [
    RegionModel(
      id: 'fallback-ng',
      name: 'Nigeria',
      countryIso: 'NG',
      phoneDialCode: '234',
    ),
  ];

  const RegionModel({
    required this.id,
    required this.name,
    required this.countryIso,
    required this.phoneDialCode,
  });

  final String id;
  final String name;
  final String countryIso;
  final String phoneDialCode;

  factory RegionModel.fromJson(Map<String, dynamic> json) {
    return RegionModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      countryIso: (json['country_iso'] ?? json['countryIso'] ?? '')
          .toString()
          .toUpperCase(),
      phoneDialCode:
          (json['phone_dial_code'] ?? json['phoneDialCode'] ?? '').toString(),
    );
  }

  String get dialCodeWithPlus {
    final d = phoneDialCode.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return '';
    return '+$d';
  }

  @override
  List<Object?> get props => [id, name, countryIso, phoneDialCode];
}
