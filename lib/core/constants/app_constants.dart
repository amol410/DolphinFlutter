class AppConstants {
  AppConstants._();

  static const String appName = 'LingoDolphy';
  static const String appVersion = '1.2.12';
  static const String tokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String apiBaseUrlKey = 'api_base_url';

  // Version & Update Control
  static const int currentBuildNumber = 17;
  static const String versionCheckUrl = 'https://dolphincoder.com/app_version.json';
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.dolphincoder.lms';

  // Google AdMob Configuration (Verified Google Play Listing)
  static const String adMobAppId = 'ca-app-pub-6038618318911032~9968150974';
  static const String adMobRewardedAdUnitId = 'ca-app-pub-6038618318911032/1291353098';
  static const String adMobInterstitialAdUnitId = 'ca-app-pub-6038618318911032/3647934028';

  // Legal & Compliance URLs
  static const String privacyPolicyUrl = 'https://dolphincoder.com/privacy';
  static const String termsOfServiceUrl = 'https://dolphincoder.com/terms';
  static const String deleteAccountUrl = 'https://dolphincoder.com/delete-account';
}
