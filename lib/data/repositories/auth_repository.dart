// auth_repository.dart
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/data/models/login_response.dart';

class AuthRepository {
  final DioClient dioClient;

  AuthRepository(this.dioClient);

  Future<LoginResponse?> login(String login, String password) async {
    try {
      final response = await dioClient.post(
        '/auth/login',
        data: {'login': login, 'password': password, 'platform': 'mobile_app'},
      );

      if (response.statusCode == 200) {
        return LoginResponse.fromJson(response.data);
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<UserModel?> getUserInfo(String token) async {
    try {
      final response = await dioClient.get('/auth/profile');

      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data);
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }
}
