import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  ApiConstants._();

  static const String defaultBaseUrl = 'http://10.0.2.2:5000/api';
  static const String productionBaseUrl = 'https://api.dolphincoder.com/api';

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String updateProfile = '/auth/profile';
  static const String changePassword = '/auth/password';

  // Content
  static const String subjects = '/subjects';
  static const String notes = '/notes';
  static const String videos = '/videos';
  static const String quizzes = '/quizzes';
  static const String flashcards = '/flashcards';

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_base_url') ?? defaultBaseUrl;
  }
}
