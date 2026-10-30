import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/app_constants.dart';
import 'models/user_model.dart';

class AuthRepository {
  static const _storage = FlutterSecureStorage();
  final GoogleSignIn _googleSignIn;

  AuthRepository({GoogleSignIn? googleSignIn})
      : _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: ['email', 'profile']);

  GoogleSignIn get googleSignIn => _googleSignIn;

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

  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        return null;
      }
      final auth = await account.authentication;
      final dio = await DioClient.getInstance();
      final response = await dio.post(
        ApiConstants.googleLogin,
        data: {
          'idToken': auth.idToken,
          'accessToken': auth.accessToken,
          'token': auth.idToken,
          'email': account.email,
          'name': account.displayName,
          'avatar': account.photoUrl,
          'photoUrl': account.photoUrl,
        },
      );
      final token = response.data['token'] as String;
      final user = UserModel.fromJson(response.data['user'] as Map<String, dynamic>);
      await _saveSession(token, user);
      return {'token': token, 'user': user};
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<void> requestPasswordResetOtp(String email) async {
    final dio = await DioClient.getInstance();
    try {
      await dio.post(ApiConstants.forgotPassword, data: {'email': email});
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<void> verifyOtp(String email, String otp) async {
    final dio = await DioClient.getInstance();
    try {
      await dio.post(ApiConstants.verifyOtp, data: {'email': email, 'otp': otp});
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<void> resetPassword(String email, String otp, String newPassword) async {
    final dio = await DioClient.getInstance();
    try {
      await dio.post(
        ApiConstants.resetPassword,
        data: {
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
          'password': newPassword,
        },
      );
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
    DioClient.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userDataKey);
    DioClient.reset();
  }

  Future<String?> getToken() async {
    if (DioClient.cachedToken != null) return DioClient.cachedToken;
    final token = await _storage.read(key: AppConstants.tokenKey);
    DioClient.setToken(token);
    return token;
  }

  Future<UserModel?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(AppConstants.userDataKey);
    if (json == null) return null;
    return UserModel.fromJsonString(json);
  }

  Future<void> _saveSession(String token, UserModel user) async {
    DioClient.setToken(token);
    await _storage.write(key: AppConstants.tokenKey, value: token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userDataKey, user.toJsonString());
  }
}
