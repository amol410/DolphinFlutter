import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../firebase_options.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../network/dio_client.dart';

/// Top-level background message handler invoked when the app receives
/// a push notification while in the background or terminated.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('⚠️ [NotificationService] Background message handler init notice: $e');
  }
  debugPrint('🔔 [NotificationService] Handling background message: ${message.messageId}');
}

/// Centralized Notification Service for DolphinCoder LMS.
/// Handles Firebase Cloud Messaging (FCM), foreground in-app presentation,
/// token registration/unregistration, and click/tap routing.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static NotificationService get instance => _instance;

  static const String channelId = 'dolphincoder_high_importance';
  static const String channelName = 'Learning & Streak Alerts';
  static const String channelDescription =
      'Notifications for daily streaks, learning reminders, and league updates';

  /// Global navigator key for routing upon notification taps
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Optional navigation callback override (useful for custom router integrations and tests)
  void Function(String route)? onNavigate;

  FirebaseMessaging? _messaging;
  bool _isInitialized = false;
  String? _currentFcmToken;
  String? _pendingRoute;

  bool get isInitialized => _isInitialized;
  String? get currentFcmToken => _currentFcmToken;
  String? get pendingRoute => _pendingRoute;

  /// Consumes and clears any pending route queued prior to router readiness.
  String? consumePendingRoute() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  /// Initialize FirebaseMessaging.
  Future<void> init() async {
    if (_isInitialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      _messaging = FirebaseMessaging.instance;

      // Register top-level background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request user notification permissions
      await requestPermissions();

      // Configure foreground presentation options on iOS
      await _messaging?.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Listen to foreground notifications to show in-app alert cards
      _setupForegroundListener();

      // Listen to notification clicks when the app is in the background
      _setupMessageOpenedAppListener();

      // Check if the app was launched by tapping a notification from terminated state
      await _checkInitialMessage();

      // Listen to token refresh events
      _setupTokenRefreshListener();

      _isInitialized = true;
      debugPrint('🔔 [NotificationService] FCM initialized successfully');

      // Attempt initial token sync if user is already logged in
      unawaited(syncTokenWithBackend().catchError((_) {}));
    } catch (e, stack) {
      debugPrint('⚠️ [NotificationService] Initialization notice: $e');
      if (kDebugMode) {
        debugPrint(stack.toString());
      }
    }
  }

  /// Request notification permissions (iOS and Android 13+)
  Future<NotificationSettings?> requestPermissions() async {
    try {
      if (_messaging == null) return null;
      final settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      debugPrint('🔔 [NotificationService] Permission status: ${settings.authorizationStatus}');
      return settings;
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error requesting notification permissions: $e');
      return null;
    }
  }

  /// Get current FCM token
  Future<String?> getToken() async {
    try {
      if (_messaging != null) {
        final token = await _messaging!.getToken();
        if (token != null && token.isNotEmpty) {
          _currentFcmToken = token;
        }
        return token;
      }
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error getting FCM token: $e');
    }
    return _currentFcmToken;
  }

  /// Synchronize FCM token with backend API (`POST /api/notifications/register-token`).
  /// Only executes if user is currently logged in.
  Future<void> syncTokenWithBackend({String? token}) async {
    try {
      final fcmToken = token ?? await getToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('🔔 [NotificationService] No FCM token available to sync.');
        return;
      }

      // Check if user is authenticated
      final authToken = DioClient.cachedToken ??
          await const FlutterSecureStorage().read(key: AppConstants.tokenKey);
      if (authToken == null || authToken.isEmpty) {
        debugPrint('🔔 [NotificationService] User not logged in; skipping FCM token registration.');
        return;
      }

      final dio = await DioClient.getInstance();
      debugPrint('🔔 [NotificationService] Registering FCM token with backend: $fcmToken');
      await dio.post(
        ApiConstants.registerFcmToken,
        data: {'fcmToken': fcmToken},
      );
      _currentFcmToken = fcmToken;
      debugPrint('🔔 [NotificationService] FCM token registered successfully with backend.');
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error registering FCM token with backend: $e');
    }
  }

  /// Unregister FCM token on user logout (`POST /api/notifications/unregister-token`).
  Future<void> clearTokenOnLogout() async {
    try {
      final tokenToClear = _currentFcmToken ?? await getToken();
      if (tokenToClear != null && tokenToClear.isNotEmpty) {
        try {
          final dio = await DioClient.getInstance();
          debugPrint('🔔 [NotificationService] Unregistering FCM token from backend: $tokenToClear');
          await dio.post(
            ApiConstants.unregisterFcmToken,
            data: {'fcmToken': tokenToClear},
          );
        } catch (e) {
          debugPrint('⚠️ [NotificationService] Error unregistering FCM token API: $e');
        }
      }

      try {
        if (_messaging != null) {
          await _messaging!.deleteToken();
        }
      } catch (e) {
        debugPrint('⚠️ [NotificationService] Error deleting FCM token: $e');
      }

      _currentFcmToken = null;
      debugPrint('🔔 [NotificationService] FCM token cleared on logout.');
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error during clearTokenOnLogout: $e');
    }
  }

  /// Show heads-up foreground notification banner
  Future<void> showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final title = notification?.title ?? message.data['title'] as String?;
      final body = notification?.body ?? message.data['body'] as String?;
      final route = message.data['route'] as String? ?? message.data['screen'] as String?;

      if (title == null && body == null) {
        return;
      }

      final context = navigatorKey?.currentContext;
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.notifications_active, color: Color(0xFF00E5FF), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                        ),
                      if (body != null)
                        Text(
                          body,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            action: route != null
                ? SnackBarAction(
                    label: 'VIEW',
                    textColor: const Color(0xFF00E5FF),
                    onPressed: () => handleRoute(route),
                  )
                : null,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error displaying foreground banner: $e');
    }
  }

  /// Handle routing to the target screen based on notification route payload
  void handleRoute(String route) {
    debugPrint('🔔 [NotificationService] Navigating to notification route: $route');
    if (onNavigate != null) {
      onNavigate!(route);
      return;
    }

    final context = navigatorKey?.currentContext;
    if (context != null && context.mounted) {
      try {
        GoRouter.of(context).go(route);
        return;
      } catch (e) {
        debugPrint('⚠️ [NotificationService] GoRouter navigation error: $e');
      }
    }

    // If context is not yet available, queue route for consumption after startup
    _pendingRoute = route;
  }

  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 [NotificationService] Foreground message received: ${message.messageId}');
      showLocalNotification(message);
    });
  }

  void _setupMessageOpenedAppListener() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 [NotificationService] onMessageOpenedApp received: ${message.messageId}');
      _handleRemoteMessageClick(message);
    });
  }

  Future<void> _checkInitialMessage() async {
    try {
      final initialMessage = await _messaging?.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('🔔 [NotificationService] getInitialMessage found: ${initialMessage.messageId}');
        _handleRemoteMessageClick(initialMessage);
      }
    } catch (e) {
      debugPrint('⚠️ [NotificationService] Error checking initial message: $e');
    }
  }

  void _setupTokenRefreshListener() {
    _messaging?.onTokenRefresh.listen((newToken) {
      debugPrint('🔔 [NotificationService] FCM token refreshed: $newToken');
      _currentFcmToken = newToken;
      syncTokenWithBackend(token: newToken);
    });
  }

  void _handleRemoteMessageClick(RemoteMessage message) {
    final route = message.data['route'] as String? ?? message.data['screen'] as String?;
    if (route != null && route.isNotEmpty) {
      handleRoute(route);
    }
  }

  @visibleForTesting
  void setInstances({
    FirebaseMessaging? messaging,
  }) {
    _messaging = messaging;
    _isInitialized = true;
  }

  @visibleForTesting
  void reset() {
    _isInitialized = false;
    _currentFcmToken = null;
    _pendingRoute = null;
    _messaging = null;
    onNavigate = null;
    navigatorKey = null;
  }
}
