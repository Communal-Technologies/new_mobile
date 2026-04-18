import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  /// Best-effort display name (full name from profile, else username).
  final String name;
  final String login;
  final String? avatar;
  final bool hasSecurityPin;
  /// Raw API role, e.g. `member`.
  final String role;
  final String? cooperativeId;
  final String? ledgerNumber;

  const UserModel({
    required this.id,
    required this.name,
    required this.login,
    this.avatar,
    this.hasSecurityPin = false,
    this.role = 'member',
    this.cooperativeId,
    this.ledgerNumber,
  });

  String get roleLabel {
    if (role.isEmpty) return 'Member';
    return role[0].toUpperCase() + role.substring(1).toLowerCase();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'];
    final userData = userMap is Map
        ? Map<String, dynamic>.from(userMap)
        : Map<String, dynamic>.from(json);
    final profileRaw = userData['profile'];
    final profile = profileRaw is Map
        ? Map<String, dynamic>.from(profileRaw)
        : null;

    final topRole = json['role']?.toString();
    final role =
        (topRole != null && topRole.isNotEmpty)
            ? topRole
            : (userData['role']?.toString() ?? 'member');

    String fullName = '';
    if (profile != null) {
      final parts = [
        profile['first_name'],
        profile['middle_name'],
        profile['last_name'],
      ]
          .map((e) => e?.toString().trim() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      fullName = parts.join(' ');
    }

    final fallbackName =
        userData['username']?.toString() ??
        userData['name']?.toString() ??
        '';

    final loginVal =
        userData['email']?.toString() ??
        userData['phone']?.toString() ??
        userData['login']?.toString() ??
        '';

    return UserModel(
      id: userData['id']?.toString() ?? '',
      name: fullName.isNotEmpty ? fullName : fallbackName,
      login: loginVal,
      avatar: profile?['avatar']?.toString(),
      hasSecurityPin:
          userData['has_security_pin'] == true ||
          userData['has_security_pin'] == 1,
      role: role,
      cooperativeId: profile?['cooperative_id']?.toString(),
      ledgerNumber: profile?['ledger_number']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'login': login,
      'avatar': avatar,
      'has_security_pin': hasSecurityPin,
      'role': role,
      'cooperative_id': cooperativeId,
      'ledger_number': ledgerNumber,
    };
  }

  @override
  List<Object?> get props => [
        id,
        name,
        login,
        avatar,
        hasSecurityPin,
        role,
        cooperativeId,
        ledgerNumber,
      ];
}
