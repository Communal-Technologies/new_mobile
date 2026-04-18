import 'package:equatable/equatable.dart';

/// Row from `GET /fetch-lgas/{stateId}` (`lgas` array).
class LgaModel extends Equatable {
  const LgaModel({
    required this.id,
    required this.stateId,
    required this.name,
  });

  final int id;
  final String stateId;
  final String name;

  factory LgaModel.fromJson(Map<String, dynamic> json) {
    return LgaModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      stateId: json['state_id']?.toString() ?? '',
      name: json['lga']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [id, stateId, name];
}
