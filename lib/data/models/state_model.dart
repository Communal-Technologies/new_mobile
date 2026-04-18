import 'package:equatable/equatable.dart';

/// Row from `GET /fetch-states` (`states` array).
class StateModel extends Equatable {
  const StateModel({
    required this.id,
    required this.name,
    this.countryIso,
  });

  final int id;
  final String name;
  final String? countryIso;

  factory StateModel.fromJson(Map<String, dynamic> json) {
    final iso = json['country_iso']?.toString().trim();
    return StateModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['state']?.toString() ?? '',
      countryIso: iso != null && iso.length == 2 ? iso.toUpperCase() : null,
    );
  }

  @override
  List<Object?> get props => [id, name, countryIso];
}
