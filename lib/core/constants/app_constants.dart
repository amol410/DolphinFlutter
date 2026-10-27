class AppConstants {
  AppConstants._();

  static const String appName = 'LingoDolphy';
  static const String appVersion = '1.2.10';
  static const String tokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String apiBaseUrlKey = 'api_base_url';

  // Version & Update Control
  static const int currentBuildNumber = 15;
  static const String versionCheckUrl = 'https://dolphincoder.com/app_version.json';
  static const String playStoreUrl = 'https://play.google.com/store/apps/details?id=com.dolphincoder.lms';

  // Google AdMob Configuration
  static const String adMobAppId = 'ca-app-pub-6038618318911032~7984081507';
  static const String adMobRewardedAdUnitId = 'ca-app-pub-6038618318911032/8796593593';
  static const String adMobInterstitialAdUnitId = 'ca-app-pub-6038618318911032/2646005241';

  // Legal & Compliance URLs
  static const String privacyPolicyUrl = 'https://dolphincoder.com/privacy';
  static const String termsOfServiceUrl = 'https://dolphincoder.com/terms';
  static const String deleteAccountUrl = 'https://dolphincoder.com/delete-account';
}
