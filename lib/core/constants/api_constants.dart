import 'package:shared_preferences/shared_preferences.dart';

class ApiConstants {
  ApiConstants._();

  static const String defaultBaseUrl = 'https://dolphincoder.com/api';
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

  // Gamification & Archipelago Path
  static const String gamificationStatus = '/gamification/status';
  static const String gamificationPath = '/gamification/path';
  static const String gamificationCompleteNode = '/gamification/complete-node';
  static const String gamificationLeaderboard = '/gamification/leaderboard';
  static const String gamificationRefillOxygen = '/gamification/shop/refill-oxygen';

  static Future<String> getBaseUrl() async {
    // Ignore any cached local IPs from previous builds to prevent connection timeouts
    return defaultBaseUrl;
  }
}
