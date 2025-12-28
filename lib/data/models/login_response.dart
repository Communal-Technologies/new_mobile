import 'package:equatable/equatable.dart';
import 'package:communal_mobile/data/models/user_model.dart';

class LoginResponse extends Equatable {
  final String? token;
  final UserModel? user;

  const LoginResponse({
    this.token,
    this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      token: json['token'] as String?,
      user: json['user'] != null 
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user': user?.toJson(),
    };
  }

  @override
  List<Object?> get props => [token, user];
}
