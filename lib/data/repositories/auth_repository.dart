// auth_repository.dart
import 'dart:developer' as developer;
import 'package:communal_mobile/data/datasources/remote/dio/dio_client.dart';
import 'package:communal_mobile/data/models/user_model.dart';
import 'package:communal_mobile/data/models/login_response.dart';
import 'package:communal_mobile/core/utils/app_logger.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  final DioClient dioClient;
  static const String _platform = 'mobile_app'; // Platform identifier for mobile app

  AuthRepository(this.dioClient);
  
  /// Update the token in DioClient for authenticated requests
  void updateToken(String token) {
    dioClient.updateToken(token);
  }

  Future<LoginResponse?> login(String login, String password) async {
    try {
      // This endpoint doesn't require authentication (public login endpoint)
      final response = await dioClient.post(
        '/login',
        data: {
          'login': login,
          'password': password,
          'platform': _platform, // Required by backend to identify platform type
        },
        requireAuth: false, // No auth required for login
      );

      if (response.statusCode == 200) {
        return LoginResponse.fromJson(response.data);
      }
    } on DioException catch (e) {
      // Extract error message from response
      if (e.response != null) {
        final statusCode = e.response?.statusCode;
        final responseData = e.response?.data;
        String errorMessage = 'Login failed. Please check your credentials.';
        
        // Handle rate limiting and account lockout (429 Too Many Requests)
        if (statusCode == 429) {
          if (responseData is Map) {
            final message = responseData['message']?.toString().toLowerCase() ?? '';
            
            // Check if it's an account lockout (from our custom security service)
            if (message.contains('locked') || message.contains('lockout')) {
              final lockedUntil = responseData['locked_until'];
              final minutesRemaining = responseData['minutes_remaining'];
              
              if (minutesRemaining != null) {
                final minutes = int.tryParse(minutesRemaining.toString()) ?? 30;
                errorMessage = 'Account temporarily locked due to multiple failed attempts. Please try again in $minutes minute${minutes > 1 ? 's' : ''}.';
              } else if (lockedUntil != null) {
                errorMessage = 'Account temporarily locked. Please try again later.';
              } else {
                errorMessage = responseData['message'] ?? 'Account temporarily locked. Please try again later.';
              }
            } else {
              // It's a rate limit from Laravel's throttle middleware
              // Check for retry-after header or provide default message
              final retryAfter = e.response?.headers.value('retry-after');
              
              if (retryAfter != null) {
                final seconds = int.tryParse(retryAfter) ?? 60;
                final minutes = (seconds / 60).ceil();
                errorMessage = 'Too many login attempts. Please wait $minutes minute${minutes > 1 ? 's' : ''} before trying again.';
              } else {
                errorMessage = responseData['message'] ?? 'Too many login attempts. Please wait a few minutes before trying again.';
              }
            }
          } else if (responseData is String) {
            final message = responseData.toLowerCase();
            if (message.contains('too many') || message.contains('throttle')) {
              errorMessage = 'Too many login attempts. Please wait a few minutes before trying again.';
            } else if (message.contains('locked') || message.contains('lockout')) {
              errorMessage = 'Account temporarily locked. Please try again later.';
            } else {
              errorMessage = responseData;
            }
          } else {
            errorMessage = 'Too many login attempts. Please wait a few minutes before trying again.';
          }
          throw Exception(errorMessage);
        }
        
        // Handle other errors
        if (responseData is Map) {
          errorMessage = responseData['message'] ?? 
                        responseData['error'] ?? 
                        (responseData['errors'] != null 
                          ? responseData['errors'].toString() 
                          : errorMessage);
        } else if (responseData is String) {
          errorMessage = responseData;
        }
        
        throw Exception(errorMessage);
      } else {
        throw Exception('Network error. Please check your connection.');
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<UserModel?> getUserInfo(String token) async {
    print('🔵 GET USER INFO - Token: ${token.substring(0, 20)}...');
    // Ensure token is set in DioClient before making the request
    updateToken(token);
    try {
      final response = await dioClient.get('/get-loggedin-user');
      print('🔵 GET USER INFO - Status: ${response.statusCode}');
      print('🔵 GET USER INFO - Data: ${response.data}');

      if (response.statusCode == 200) {
        try {
          // The response structure is {user: {...}} or just {...}
          final user = UserModel.fromJson(response.data);
          print('✅ GET USER INFO - User parsed: ${user.id}');
          print('✅ GET USER INFO - Has security pin: ${user.hasSecurityPin}');
          print('✅ GET USER INFO - Avatar: ${user.avatar}');
          return user;
        } catch (parseError) {
          print('❌ GET USER INFO - Parse error: $parseError');
          print('❌ GET USER INFO - Data: ${response.data}');
          rethrow;
        }
      }
    } on DioException catch (e) {
      print('❌ GET USER INFO - DioException');
      print('❌ Status: ${e.response?.statusCode}');
      print('❌ Data: ${e.response?.data}');
      rethrow;
    } catch (e, stackTrace) {
      print('❌ GET USER INFO - Error: $e');
      print('❌ Stack: $stackTrace');
      rethrow;
    }
    return null;
  }

  Future<Map<String, dynamic>?> checkLogin(String login) async {
    try {
      // This endpoint doesn't require authentication
      final response = await dioClient.post(
        '/login-checker',
        data: {'login': login, 'user': 'member'},
        requireAuth: false, // No auth required for login check
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'hasPassword': response.data['password'] == 1,
          'userId': response.data['login']['id'].toString(),
          'login': login,
        };
      }
    } on DioException catch (e) {
      // Extract error message from response
      if (e.response != null) {
        final errorMessage = e.response?.data['message'] ?? 
                           e.response?.data['error'] ?? 
                           'User not found';
        throw Exception(errorMessage);
      } else {
        throw Exception('Network error. Please check your connection.');
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<bool> verifyOtp(String contact, String otp, bool isEmail) async {
    try {
      // For now, accept any OTP as mentioned by user
      // TODO: Implement actual OTP verification when backend is ready
      return true;
    } catch (e) {
      rethrow;
    }
  }

  Future<LoginResponse?> createPassword(String userId, String password) async {
    developer.log('🚀🚀🚀 CREATE PASSWORD METHOD CALLED 🚀🚀🚀', name: 'AuthRepository');
    developer.log('🚀 User ID: $userId', name: 'AuthRepository');
    appLog('CREATE PASSWORD METHOD CALLED', 'User ID: $userId');
    try {
      developer.log('=== CREATE PASSWORD REQUEST ===', name: 'AuthRepository');
      developer.log('User ID: $userId', name: 'AuthRepository');
      developer.log('Request URL: /create-account-password', name: 'AuthRepository');
      appLog('CREATE PASSWORD REQUEST', 'User ID: $userId, URL: /create-account-password');
      print('=== CREATE PASSWORD REQUEST ===');
      print('User ID: $userId');
      print('Request URL: /create-account-password');
      print('Request Data: {user: $userId, password: ***, new_password: ***}');
      debugPrint('=== CREATE PASSWORD REQUEST ===');
      debugPrint('User ID: $userId');
      debugPrint('Request URL: /create-account-password');
      debugPrint('Request Data: {user: $userId, password: ***, new_password: ***}');
      
      // This endpoint doesn't require authentication (user doesn't have password yet)
      final response = await dioClient.post(
        '/create-account-password',
        data: {
          'user': userId,
          'password': password,
          'new_password': password,
          'platform': 'mobile_app', // Indicate this is from mobile app
        },
        requireAuth: false, // No auth required for password creation
      );

      print('=== CREATE PASSWORD RESPONSE ===');
      print('Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');
      print('Response Data Type: ${response.data.runtimeType}');
      debugPrint('=== CREATE PASSWORD RESPONSE ===');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Headers: ${response.headers}');
      debugPrint('Response Data: ${response.data}');
      debugPrint('Response Data Type: ${response.data.runtimeType}');
      
      if (response.statusCode == 200) {
        print('✅ Response is 200 OK');
        print('✅ Full response data: ${response.data}');
        debugPrint('Response is 200 OK');
        debugPrint('Full response data: ${response.data}');
        
        // Check if token is returned
        if (response.data != null && response.data is Map) {
          final responseData = response.data as Map<String, dynamic>;
          print('✅ Response data is Map');
          print('✅ Response keys: ${responseData.keys.toList()}');
          debugPrint('Response data is Map, checking for token...');
          debugPrint('Response keys: ${responseData.keys.toList()}');
          
          if (responseData['token'] != null) {
            print('✅ Token found in response');
            print('✅ Token value: ${responseData['token']}');
            debugPrint('Token found in response: ${responseData['token']}');
            
            try {
              // Try to parse user if available
              UserModel? user;
              if (responseData['user'] != null && responseData['user'] is Map) {
                try {
                  user = UserModel.fromJson(responseData['user'] as Map<String, dynamic>);
                  print('✅ User parsed successfully');
                } catch (userParseError) {
                  print('⚠️ User parsing failed: $userParseError');
                  print('⚠️ User data: ${responseData['user']}');
                  // Continue without user, will fetch separately
                }
              }
              
              final loginResponse = LoginResponse(
                token: responseData['token'] as String?,
                user: user,
              );
              print('✅ LoginResponse created successfully');
              debugPrint('LoginResponse created successfully');
              return loginResponse;
            } catch (parseError, stackTrace) {
              print('❌ Error parsing LoginResponse: $parseError');
              print('❌ Stack trace: $stackTrace');
              print('❌ Response data structure: $responseData');
              debugPrint('Error parsing LoginResponse: $parseError');
              debugPrint('Response data structure: $responseData');
              // Even if parsing fails, return a response with the token
              return LoginResponse(
                token: responseData['token'] as String?,
                user: null, // Will be fetched separately
              );
            }
          } else {
            print('⚠️ No token in response, will login separately');
            print('⚠️ Available keys: ${responseData.keys.toList()}');
            debugPrint('No token in response, will login separately');
            debugPrint('Available keys: ${responseData.keys.toList()}');
            // If no token, return null and we'll login separately
            return null;
          }
        } else {
          print('❌ Response data is not a Map, type: ${response.data.runtimeType}');
          debugPrint('Response data is not a Map, type: ${response.data.runtimeType}');
          return null;
        }
      } else {
        print('❌ Unexpected status code: ${response.statusCode}');
        debugPrint('Unexpected status code: ${response.statusCode}');
        return null;
      }
    } on DioException catch (e) {
      developer.log('❌ === CREATE PASSWORD DIO ERROR ===', name: 'AuthRepository');
      developer.log('❌ Error Type: ${e.type}', name: 'AuthRepository');
      developer.log('❌ Error Message: ${e.message}', name: 'AuthRepository');
      developer.log('❌ Status Code: ${e.response?.statusCode}', name: 'AuthRepository');
      developer.log('❌ Response Data: ${e.response?.data}', name: 'AuthRepository');
      appLog('CREATE PASSWORD DIO ERROR', 'Type: ${e.type}, Message: ${e.message}, Status: ${e.response?.statusCode}');
      print('❌ === CREATE PASSWORD DIO ERROR ===');
      print('❌ Error Type: ${e.type}');
      print('❌ Error Message: ${e.message}');
      print('❌ Status Code: ${e.response?.statusCode}');
      print('❌ Response Data: ${e.response?.data}');
      debugPrint('=== CREATE PASSWORD ERROR ===');
      debugPrint('Error Type: ${e.type}');
      debugPrint('Error Message: ${e.message}');
      debugPrint('Status Code: ${e.response?.statusCode}');
      debugPrint('Response Data: ${e.response?.data}');
      
      // Extract error message from response
      if (e.response != null) {
        print('❌ Response Status Code: ${e.response?.statusCode}');
        print('❌ Response Data: ${e.response?.data}');
        print('❌ Response Data Type: ${e.response?.data.runtimeType}');
        debugPrint('Response Status Code: ${e.response?.statusCode}');
        debugPrint('Response Headers: ${e.response?.headers}');
        debugPrint('Response Data: ${e.response?.data}');
        debugPrint('Response Data Type: ${e.response?.data.runtimeType}');
        
        final responseData = e.response?.data;
        String errorMessage = 'Failed to create password';
        
        if (responseData is Map) {
          errorMessage = responseData['message'] ?? 
                        responseData['error'] ?? 
                        (responseData['errors'] != null 
                          ? responseData['errors'].toString() 
                          : errorMessage);
        } else if (responseData is String) {
          errorMessage = responseData;
        }
        
        print('❌ Extracted Error Message: $errorMessage');
        debugPrint('Extracted Error Message: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('❌ No response in error, network issue');
        debugPrint('No response in error, network issue');
        throw Exception('Network error. Please check your connection.');
      }
    } catch (e, stackTrace) {
      print('❌ === CREATE PASSWORD UNEXPECTED ERROR ===');
      print('❌ Error: $e');
      print('❌ Error Type: ${e.runtimeType}');
      print('❌ Stack Trace: $stackTrace');
      debugPrint('=== CREATE PASSWORD UNEXPECTED ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Error Type: ${e.runtimeType}');
      debugPrint('Stack Trace: $stackTrace');
      rethrow;
    }
  }

  Future<bool> resetPassword(String login, String newPassword) async {
    try {
      developer.log('=== RESET PASSWORD REQUEST ===', name: 'AuthRepository');
      developer.log('Login: $login', name: 'AuthRepository');
      developer.log('Password length: ${newPassword.length}', name: 'AuthRepository');
      appLog('RESET PASSWORD REQUEST', 'Login: $login, Password length: ${newPassword.length}');
      print('=== RESET PASSWORD REQUEST ===');
      print('Login: $login');
      print('Password length: ${newPassword.length}');
      print('Request URL: /reset-password');
      print('Request method: PUT');
      
      // This endpoint doesn't require authentication (user is resetting password)
      // Note: Backend uses PUT method
      final response = await dioClient.put(
        '/reset-password',
        data: {
          'login': login,
          'new_password': newPassword,
          'platform': _platform, // Indicate this is from mobile app
        },
        requireAuth: false, // No auth required for password reset
      );

      print('=== RESET PASSWORD RESPONSE ===');
      print('Status Code: ${response.statusCode}');
      print('Response Data: ${response.data}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = response.data;
        // Check for success message or just status code 200/201
        if (responseData is Map) {
          final message = responseData['message']?.toString().toLowerCase() ?? '';
          if (message.contains('success') || message.contains('updated') || responseData['status'] == true) {
            developer.log('✅ Password reset successful', name: 'AuthRepository');
            appLog('RESET PASSWORD SUCCESS', responseData['message'] ?? 'Password updated');
            return true;
          } else if (responseData['message'] != null) {
            // Has a message but might not contain "success" - still consider it success if status is 200
            developer.log('✅ Password reset successful (status 200)', name: 'AuthRepository');
            appLog('RESET PASSWORD SUCCESS', responseData['message']);
            return true;
          }
        } else {
          // If response is not a map but status is 200, consider it success
          developer.log('✅ Password reset successful (status 200, non-map response)', name: 'AuthRepository');
          appLog('RESET PASSWORD SUCCESS', 'Status: ${response.statusCode}');
          return true;
        }
      }
      print('⚠️ RESET PASSWORD: Unexpected response format or status code');
      return false;
    } on DioException catch (e) {
      developer.log('❌ === RESET PASSWORD DIO ERROR ===', name: 'AuthRepository');
      developer.log('❌ Error Type: ${e.type}', name: 'AuthRepository');
      developer.log('❌ Error Message: ${e.message}', name: 'AuthRepository');
      developer.log('❌ Status Code: ${e.response?.statusCode}', name: 'AuthRepository');
      developer.log('❌ Response Data: ${e.response?.data}', name: 'AuthRepository');
      appLog('RESET PASSWORD DIO ERROR', 'Type: ${e.type}, Message: ${e.message}, Status: ${e.response?.statusCode}');
      print('❌ === RESET PASSWORD DIO ERROR ===');
      print('❌ Error Type: ${e.type}');
      print('❌ Error Message: ${e.message}');
      print('❌ Status Code: ${e.response?.statusCode}');
      print('❌ Response Data: ${e.response?.data}');
      
      // Extract error message from response
      if (e.response != null) {
        final responseData = e.response?.data;
        String errorMessage = 'Unable to reset password. Please try again.';
        
        if (responseData is Map) {
          errorMessage = responseData['message'] ?? 
                        responseData['error'] ?? 
                        (responseData['errors'] != null 
                          ? responseData['errors'].toString() 
                          : errorMessage);
        } else if (responseData is String) {
          errorMessage = responseData;
        }
        
        throw Exception(errorMessage);
      }
      
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      developer.log('❌ RESET PASSWORD ERROR: $e', name: 'AuthRepository');
      appLog('RESET PASSWORD ERROR', e.toString());
      rethrow;
    }
  }
}
