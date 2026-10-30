import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

/// Centralized service for Google Analytics & Firebase Crashlytics
class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  FirebaseAnalytics? _analytics;
  FirebaseCrashlytics? _crashlytics;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  FirebaseAnalytics get analytics => _analytics ?? FirebaseAnalytics.instance;
  FirebaseCrashlytics get crashlytics =>
      _crashlytics ?? FirebaseCrashlytics.instance;

  NavigatorObserver? _observer;

  /// Route observer for GoRouter to automatically track screen transitions.
  /// Falls back to a standard NavigatorObserver during headless unit tests.
  NavigatorObserver get observer {
    if (_isInitialized && _analytics != null) {
      _observer ??= FirebaseAnalyticsObserver(analytics: _analytics!);
      return _observer!;
    }
    return NavigatorObserver();
  }

  /// Initialize Firebase Core, Google Analytics, and Firebase Crashlytics
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      _analytics = FirebaseAnalytics.instance;
      _crashlytics = FirebaseCrashlytics.instance;

      // Enable collection
      await _analytics?.setAnalyticsCollectionEnabled(true);

      // In debug mode, optionally disable crash collection or keep active for testing
      await _crashlytics?.setCrashlyticsCollectionEnabled(!kDebugMode || true);

      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        _crashlytics?.recordFlutterFatalError(details);
      };

      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        _crashlytics?.recordError(error, stack, fatal: true);
        return true;
      };

      _isInitialized = true;
      debugPrint('🔥 [AnalyticsService] Firebase Analytics & Crashlytics initialized successfully');
    } catch (e, stack) {
      debugPrint('⚠️ [AnalyticsService] Firebase initialization notice: $e');
      if (kDebugMode) {
        debugPrint(stack.toString());
      }
    }
  }

  /// Associate crashes and analytics with a user ID (cleared on logout)
  Future<void> setUserIdentifier(String? userId) async {
    try {
      await _analytics?.setUserId(id: userId);
      if (userId != null) {
        await _crashlytics?.setUserIdentifier(userId);
      }
    } catch (e) {
      debugPrint('Error setting user identifier: $e');
    }
  }

  /// Log custom domain events
  Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics?.logEvent(name: name, parameters: parameters);
    } catch (e) {
      debugPrint('Error logging analytics event $name: $e');
    }
  }

  /// Track lesson completion
  Future<void> logLessonCompleted({
    required String lessonId,
    required String stageType,
    required int score,
  }) async {
    await logEvent(
      name: 'lesson_completed',
      parameters: {
        'lesson_id': lessonId,
        'stage_type': stageType,
        'score': score,
      },
    );
  }

  /// Track ad reward claims
  Future<void> logAdRewardClaimed({
    required String rewardType,
    required int amount,
  }) async {
    await logEvent(
      name: 'ad_reward_claimed',
      parameters: {
        'reward_type': rewardType,
        'amount': amount,
      },
    );
  }

  /// Record a non-fatal caught error in Crashlytics
  Future<void> recordNonFatalError(
    dynamic error,
    StackTrace? stack, {
    String? reason,
  }) async {
    try {
      await _crashlytics?.recordError(error, stack, reason: reason, fatal: false);
    } catch (e) {
      debugPrint('Error recording non-fatal error to Crashlytics: $e');
    }
  }
}
