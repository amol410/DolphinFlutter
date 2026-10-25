import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedAd? _rewardedAd;
  bool _isRewardedLoading = false;
  int _numConsecutiveLoadAttempts = 0;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoading = false;
  int _numConsecutiveInterstitialLoadAttempts = 0;

  static const int _maxFailedLoadAttempts = 3;

  // Duolingo-style Lesson Frequency Counter
  static const String _kLessonCounterKey = 'lessons_completed_since_last_ad';
  static const int _kLessonsPerAd = 2; // Show interstitial ad every 2 completed lessons

  static int get lessonsPerAd => _kLessonsPerAd;

  /// Ad Unit ID for rewarded ads
  static String get rewardedAdUnitId {
    if (kDebugMode) {
      // Official Google test rewarded ad IDs in debug to prevent AdMob account flags during development
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'
          : 'ca-app-pub-3940256099942544/1712485313';
    }
    // Production rewarded ad unit ID
    return AppConstants.adMobRewardedAdUnitId;
  }

  /// Ad Unit ID for interstitial ads
  static String get interstitialAdUnitId {
    if (kDebugMode) {
      // Official Google test interstitial ad IDs in debug to prevent AdMob account flags during development
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/1033173712'
          : 'ca-app-pub-3940256099942544/4411468910';
    }
    // Production interstitial ad unit ID
    return AppConstants.adMobInterstitialAdUnitId;
  }

  /// Initialize Google Mobile Ads SDK and preload rewarded & interstitial ads
  Future<void> init() async {
    try {
      await MobileAds.instance.initialize();
      loadRewardedAd();
      await loadInterstitialAd();
    } catch (e) {
      debugPrint('AdService init error: $e');
    }
  }

  // ==========================================
  // Rewarded Ad Management
  // ==========================================

  /// Whether a rewarded ad is cached and ready to display
  bool get isRewardedAdAvailable => _rewardedAd != null;

  /// Preload a rewarded ad into memory
  void loadRewardedAd() {
    if (_rewardedAd != null || _isRewardedLoading) return;
    _isRewardedLoading = true;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedLoading = false;
          _numConsecutiveLoadAttempts = 0;
          debugPrint('RewardedAd loaded successfully ($rewardedAdUnitId)');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isRewardedLoading = false;
          _numConsecutiveLoadAttempts++;
          debugPrint('RewardedAd failed to load: ${error.message} (attempt $_numConsecutiveLoadAttempts)');
          if (_numConsecutiveLoadAttempts < _maxFailedLoadAttempts) {
            Future.delayed(
              Duration(seconds: _numConsecutiveLoadAttempts * 2),
              loadRewardedAd,
            );
          }
        },
      ),
    );
  }

  /// Show the rewarded ad to the learner
  void showRewardedAd({
    required Function() onUserEarnedReward,
    Function(String message)? onAdDismissed,
    Function(String error)? onAdFailed,
  }) {
    if (_rewardedAd == null) {
      loadRewardedAd();
      onAdFailed?.call('Ad is preparing, please try again in a few seconds.');
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('RewardedAd shown full screen');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Preload next ad
        onAdDismissed?.call('Ad closed');
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd(); // Preload next ad
        onAdFailed?.call('Failed to display ad: ${error.message}');
      },
    );

    _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        debugPrint('User earned reward: ${reward.amount} ${reward.type}');
        onUserEarnedReward();
      },
    );
  }

  // ==========================================
  // Interstitial Ad Management
  // ==========================================

  /// Whether an interstitial ad is cached and ready to display
  bool get isInterstitialAdAvailable => _interstitialAd != null;

  /// Preload an interstitial ad into memory
  Future<void> loadInterstitialAd() async {
    if (_interstitialAd != null || _isInterstitialAdLoading) return;
    _isInterstitialAdLoading = true;

    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitialAd = ad;
            _isInterstitialAdLoading = false;
            _numConsecutiveInterstitialLoadAttempts = 0;
            debugPrint('InterstitialAd loaded successfully ($interstitialAdUnitId)');
          },
          onAdFailedToLoad: (error) {
            _interstitialAd = null;
            _isInterstitialAdLoading = false;
            _numConsecutiveInterstitialLoadAttempts++;
            debugPrint('InterstitialAd failed to load: ${error.message} (attempt $_numConsecutiveInterstitialLoadAttempts)');
            if (_numConsecutiveInterstitialLoadAttempts < _maxFailedLoadAttempts) {
              Future.delayed(
                Duration(seconds: _numConsecutiveInterstitialLoadAttempts * 2),
                loadInterstitialAd,
              );
            }
          },
        ),
      );
    } catch (e) {
      _isInterstitialAdLoading = false;
      debugPrint('InterstitialAd load exception: $e');
    }
  }

  /// Show the interstitial ad to the learner
  void showInterstitialAd({
    VoidCallback? onAdDismissed,
    Function(String error)? onAdFailed,
  }) {
    if (_interstitialAd == null) {
      loadInterstitialAd();
      onAdFailed?.call('Interstitial ad is preparing, please try again in a few seconds.');
      return;
    }

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('InterstitialAd shown full screen');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Preload next interstitial ad
        onAdDismissed?.call();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitialAd = null;
        loadInterstitialAd(); // Preload next interstitial ad
        onAdFailed?.call('Failed to display interstitial ad: ${error.message}');
      },
    );

    _interstitialAd!.setImmersiveMode(true);
    _interstitialAd!.show();
  }

  // ==========================================
  // Duolingo-style Lesson Cadence
  // ==========================================

  /// Increments the count of lessons completed since the last interstitial ad was shown.
  /// Returns the updated counter value.
  Future<int> incrementLessonCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt(_kLessonCounterKey) ?? 0;
      final updated = current + 1;
      await prefs.setInt(_kLessonCounterKey, updated);
      debugPrint('AdService: incrementLessonCount -> $updated/$_kLessonsPerAd');
      return updated;
    } catch (e) {
      debugPrint('AdService incrementLessonCount error: $e');
      return 0;
    }
  }

  /// Checks whether the user has completed enough lessons to trigger an interstitial ad.
  Future<bool> shouldShowLessonInterstitial() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_kLessonCounterKey) ?? 0;
      return count >= _kLessonsPerAd;
    } catch (e) {
      debugPrint('AdService shouldShowLessonInterstitial error: $e');
      return false;
    }
  }

  /// Resets the completed lesson counter back to zero.
  Future<void> resetLessonCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLessonCounterKey, 0);
      debugPrint('AdService: resetLessonCount -> 0');
    } catch (e) {
      debugPrint('AdService resetLessonCount error: $e');
    }
  }

  /// Current number of completed lessons since the last interstitial ad
  Future<int> getLessonCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_kLessonCounterKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Duolingo-style lesson cadence:
  /// Evaluates if an interstitial ad should be displayed based on the lesson counter.
  /// If eligible and an ad is cached, it resets the counter and presents the ad.
  /// Once dismissed or failed (or if ineligible), [onDone] is guaranteed to be invoked.
  Future<void> showInterstitialIfEligible({VoidCallback? onDone}) async {
    try {
      final eligible = await shouldShowLessonInterstitial();
      if (!eligible) {
        onDone?.call();
        return;
      }

      if (!isInterstitialAdAvailable) {
        debugPrint('AdService: Eligible for interstitial ad, but ad is not ready yet. Preloading and continuing.');
        loadInterstitialAd();
        onDone?.call();
        return;
      }

      await resetLessonCount();
      showInterstitialAd(
        onAdDismissed: () {
          onDone?.call();
        },
        onAdFailed: (error) {
          debugPrint('AdService: showInterstitialIfEligible ad failed: $error');
          onDone?.call();
        },
      );
    } catch (e) {
      debugPrint('AdService showInterstitialIfEligible exception: $e');
      onDone?.call();
    }
  }

  /// Clean up loaded ads if needed
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _interstitialAd?.dispose();
    _interstitialAd = null;
  }
}
