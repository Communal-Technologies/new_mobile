import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final String login;
  final String? avatar;
  final bool hasSecurityPin;

  const UserModel({
    required this.id,
    required this.name,
    required this.login,
    this.avatar,
    this.hasSecurityPin = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle nested user structure from get-loggedin-user endpoint
    final userData = json['user'] ?? json;
    final profile = userData['profile'] as Map<String, dynamic>?;
    
    return UserModel(
      id: userData['id']?.toString() ?? '',
      name: userData['username']?.toString() ?? 
            userData['name']?.toString() ?? 
            '${profile?['first_name'] ?? ''} ${profile?['last_name'] ?? ''}'.trim(),
      login: userData['email']?.toString() ?? 
             userData['phone']?.toString() ?? 
             userData['login']?.toString() ?? '',
      avatar: profile?['avatar']?.toString(),
      hasSecurityPin: userData['has_security_pin'] == true || userData['has_security_pin'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'login': login,
      'avatar': avatar,
      'has_security_pin': hasSecurityPin,
    };
  }

  @override
  List<Object?> get props => [id, name, login, avatar, hasSecurityPin];
}
