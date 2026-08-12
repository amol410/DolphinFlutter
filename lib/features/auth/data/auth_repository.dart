import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_constants.dart';
import 'models/user_model.dart';

class AuthRepository {
  static const _storage = FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.post(ApiConstants.login,
          data: {'email': email, 'password': password});
      final token = response.data['token'] as String;
      final user = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
      await _saveSession(token, user);
      return {'token': token, 'user': user};
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.post(ApiConstants.register,
          data: {'name': name, 'email': email, 'password': password});
      final token = response.data['token'] as String;
      final user = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
      await _saveSession(token, user);
      return {'token': token, 'user': user};
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<UserModel> getMe() async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.get(ApiConstants.me);
      return UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<UserModel> updateProfile(String name, String bio) async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.put(ApiConstants.updateProfile,
          data: {'name': name, 'bio': bio});
      final user = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.userDataKey, user.toJsonString());
      return user;
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final dio = await DioClient.getInstance();
    try {
      await dio.put(ApiConstants.changePassword,
          data: {'currentPassword': currentPassword, 'newPassword': newPassword});
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConstants.tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userDataKey);
    DioClient.reset();
  }

  Future<String?> getToken() => _storage.read(key: AppConstants.tokenKey);

  Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(AppConstants.userDataKey);
    if (json == null) return null;
    return UserModel.fromJsonString(json);
  }

  Future<void> _saveSession(String token, UserModel user) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userDataKey, user.toJsonString());
  }
}
