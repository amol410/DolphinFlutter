class ApiConstants {
  ApiConstants._();

  static const String productionBaseUrl = 'https://dolphincoder.com/api';
  static const String testingBaseUrl = 'https://testing.dolphincoder.com/api';
  static const String defaultBaseUrl = productionBaseUrl;

  static bool get isTesting => defaultBaseUrl.contains('testing');

  // Auth
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String me = '/auth/me';
  static const String updateProfile = '/auth/profile';
  static const String changePassword = '/auth/password';
  static const String googleLogin = '/auth/google-login';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyOtp = '/auth/verify-otp';
  static const String resetPassword = '/auth/reset-password';
  static const String verifyRegistrationOtp = '/auth/verify-registration-otp';
  static const String resendRegistrationOtp = '/auth/resend-registration-otp';

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
  static const String gamificationDeductOxygen = '/gamification/deduct-oxygen';
  static const String gamificationBuyStreakFreeze = '/gamification/shop/buy-streak-freeze';
  static const String gamificationBuyDoubleXp = '/gamification/shop/buy-double-xp';
  static const String gamificationQuests = '/gamification/quests';
  static const String gamificationClaimQuest = '/gamification/claim-quest';
  static const String gamificationSwitchCourse = '/gamification/switch-course';
  static const String gamificationLesson = '/gamification/lesson';
  static const String gamificationClaimAdReward = '/gamification/claim-ad-reward';
  static const String gamificationPlacementQuestions = '/gamification/placement/questions';
  static const String gamificationPlacementEvaluate = '/gamification/placement/evaluate';
  static const String gamificationJumpSection = '/gamification/jump-section';

  // Notifications
  static const String registerFcmToken = '/notifications/register-token';
  static const String unregisterFcmToken = '/notifications/unregister-token';

  static Future<String> getBaseUrl() async {
    // Ignore any cached local IPs from previous builds to prevent connection timeouts
    return defaultBaseUrl;
  }
}
