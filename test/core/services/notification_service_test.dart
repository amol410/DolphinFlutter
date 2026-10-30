import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dolphincoder/core/constants/api_constants.dart';
import 'package:dolphincoder/core/constants/app_constants.dart';
import 'package:dolphincoder/core/network/dio_client.dart';
import 'package:dolphincoder/core/services/notification_service.dart';

class MockNotificationHttpAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  MockNotificationHttpAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DioClient.reset();
    NotificationService.instance.reset();
  });

  tearDown(() {
    NotificationService.instance.reset();
  });

  group('NotificationService Configuration & Singleton Tests', () {
    test('returns identical singleton instance', () {
      final s1 = NotificationService();
      final s2 = NotificationService.instance;
      expect(identical(s1, s2), isTrue);
    });

    test('high-importance notification channel is configured accurately', () {
      expect(NotificationService.channelId, equals('dolphincoder_high_importance'));
      expect(NotificationService.channelName, equals('Learning & Streak Alerts'));
      expect(NotificationService.channelDescription, contains('daily streaks'));
    });
  });

  group('NotificationService Route & Tap Handling Tests', () {
    test('routes through onNavigate callback when registered', () {
      final service = NotificationService.instance;
      String? routedPath;
      service.onNavigate = (route) {
        routedPath = route;
      };

      service.handleRoute('/leagues');
      expect(routedPath, equals('/leagues'));
      expect(service.pendingRoute, isNull);
    });

    test('queues pendingRoute and consumePendingRoute clears it', () {
      final service = NotificationService.instance;
      service.handleRoute('/shop');
      expect(service.pendingRoute, equals('/shop'));

      final consumed = service.consumePendingRoute();
      expect(consumed, equals('/shop'));
      expect(service.pendingRoute, isNull);

      final secondConsumed = service.consumePendingRoute();
      expect(secondConsumed, isNull);
    });
  });

  group('NotificationService FCM Backend Sync Tests', () {
    test('syncTokenWithBackend skips registration when no FCM token available', () async {
      final dio = await DioClient.getInstance();
      bool requestSent = false;
      dio.httpClientAdapter = MockNotificationHttpAdapter((options) async {
        requestSent = true;
        return ResponseBody.fromString('{}', 200);
      });

      final service = NotificationService.instance;
      await service.syncTokenWithBackend();

      expect(requestSent, isFalse);
    });

    test('syncTokenWithBackend skips registration when user is not logged in', () async {
      final dio = await DioClient.getInstance();
      bool requestSent = false;
      dio.httpClientAdapter = MockNotificationHttpAdapter((options) async {
        requestSent = true;
        return ResponseBody.fromString('{}', 200);
      });

      final service = NotificationService.instance;
      await service.syncTokenWithBackend(token: 'sample_fcm_token_123');

      expect(requestSent, isFalse);
    });

    test('syncTokenWithBackend registers token when user is authenticated', () async {
      DioClient.setToken('auth_bearer_token_xyz');

      RequestOptions? recordedRequest;
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockNotificationHttpAdapter((options) async {
        recordedRequest = options;
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'Token registered'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final service = NotificationService.instance;
      await service.syncTokenWithBackend(token: 'fcm_token_abc_789');

      expect(recordedRequest, isNotNull);
      expect(recordedRequest!.path, equals(ApiConstants.registerFcmToken));
      expect(recordedRequest!.data, equals({'fcmToken': 'fcm_token_abc_789'}));
      expect(service.currentFcmToken, equals('fcm_token_abc_789'));
    });

    test('clearTokenOnLogout unregisters token and resets state', () async {
      DioClient.setToken('auth_bearer_token_xyz');

      RequestOptions? recordedRequest;
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockNotificationHttpAdapter((options) async {
        recordedRequest = options;
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'message': 'Token unregistered'}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final service = NotificationService.instance;
      // Pre-set token
      await service.syncTokenWithBackend(token: 'fcm_to_delete_555');
      expect(service.currentFcmToken, equals('fcm_to_delete_555'));

      // Now clear
      await service.clearTokenOnLogout();

      expect(recordedRequest, isNotNull);
      expect(recordedRequest!.path, equals(ApiConstants.unregisterFcmToken));
      expect(recordedRequest!.data, equals({'fcmToken': 'fcm_to_delete_555'}));
      expect(service.currentFcmToken, isNull);
    });
  });
}
