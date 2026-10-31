import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolphincoder/core/constants/api_constants.dart';
import 'package:dolphincoder/core/network/dio_client.dart';
import 'package:dolphincoder/core/services/cache_service.dart';
import 'package:dolphincoder/features/gamification/data/gamification_repository.dart';
import 'package:dolphincoder/features/gamification/data/models/gamification_models.dart';
import 'package:dolphincoder/features/gamification/providers/gamification_provider.dart';

/// Custom Mock HTTP Adapter for intercepting and asserting Dio requests.
class MockDeductAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  MockDeductAdapter(this.onFetch);

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

/// Fake GamificationRepository to test GamificationStatusNotifier in isolation.
class FakeGamificationRepository extends GamificationRepository {
  int deductCallCount = 0;
  bool shouldSucceedDeduct = true;
  bool shouldThrowDeduct = false;
  GamificationStatusModel currentStatus;

  FakeGamificationRepository({
    this.currentStatus = const GamificationStatusModel(oxygen: 5, pearls: 100),
  });

  @override
  Future<GamificationStatusModel> getStatus() async {
    return currentStatus;
  }

  @override
  Future<bool> deductOxygen() async {
    deductCallCount++;
    if (shouldThrowDeduct) {
      throw Exception('Simulated fatal network error during deductOxygen');
    }
    return shouldSucceedDeduct;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempTestDir;

  setUpAll(() {
    const channelPath = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelPath, (MethodCall methodCall) async => '.');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempTestDir = Directory.systemTemp.createTempSync('dolphin_phase1_test_');
    CacheService().setAudioCacheDir(tempTestDir);
    CacheService().reset();
    await CacheService().setActiveUser('test_student_user_123');
    DioClient.reset();
  });

  tearDown(() {
    try {
      if (tempTestDir.existsSync()) {
        tempTestDir.deleteSync(recursive: true);
      }
    } catch (_) {}
    DioClient.reset();
  });

  /* =========================================================================
   * 1. GamificationRepository.deductOxygen() Network Layer Tests
   * ========================================================================= */
  group('1. GamificationRepository.deductOxygen() Network Tests', () {
    test('sends POST to /gamification/deduct-oxygen and returns true on success', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      String? requestedPath;
      String? requestedMethod;

      dio.httpClientAdapter = MockDeductAdapter((options) async {
        requestedPath = options.path;
        requestedMethod = options.method;

        final responseBody = jsonEncode({
          'success': true,
          'oxygen': 4,
          'message': 'Oxygen deducted successfully',
        });

        return ResponseBody.fromString(
          responseBody,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      final result = await repo.deductOxygen();

      expect(result, isTrue);
      expect(requestedPath, equals(ApiConstants.gamificationDeductOxygen));
      expect(requestedMethod, equals('POST'));
    });

    test('returns false when server responds with success=false', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));

      dio.httpClientAdapter = MockDeductAdapter((options) async {
        final responseBody = jsonEncode({
          'success': false,
          'message': 'Cannot deduct oxygen: user at zero',
        });

        return ResponseBody.fromString(
          responseBody,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      final result = await repo.deductOxygen();

      expect(result, isFalse);
    });

    test('returns false when server returns HTTP 500 error', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));

      dio.httpClientAdapter = MockDeductAdapter((options) async {
        final responseBody = jsonEncode({
          'success': false,
          'message': 'Internal database deadlock',
        });

        return ResponseBody.fromString(
          responseBody,
          500,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      final result = await repo.deductOxygen();

      expect(result, isFalse);
    });

    test('returns false when server returns HTTP 401 unauthenticated', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));

      dio.httpClientAdapter = MockDeductAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({'success': false, 'message': 'Not authorized'}),
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      final result = await repo.deductOxygen();

      expect(result, isFalse);
    });

    test('resilient to DioException network timeout without throwing', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));

      dio.httpClientAdapter = MockDeductAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
          error: 'Connection timed out to Hostinger server',
        );
      });

      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      final result = await repo.deductOxygen();

      expect(result, isFalse);
    });

    test('resilient to arbitrary exceptions without throwing', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));

      dio.httpClientAdapter = MockDeductAdapter((options) async {
        throw const SocketException('No Internet Connection');
      });

      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      final result = await repo.deductOxygen();

      expect(result, isFalse);
    });
  });

  /* =========================================================================
   * 2. GamificationStatusNotifier.deductOxygen() State & Provider Tests
   * ========================================================================= */
  group('2. GamificationStatusNotifier.deductOxygen() State & Provider Tests', () {
    test('decrements oxygen in provider state immediately and syncs with server', () async {
      final fakeRepo = FakeGamificationRepository(
        currentStatus: const GamificationStatusModel(oxygen: 5, pearls: 80),
      );

      final notifier = GamificationStatusNotifier(fakeRepo);
      // Wait for initial refresh() to load state
      await notifier.refresh();

      expect(notifier.state.value?.oxygen, equals(5));

      // Trigger deductOxygen
      notifier.deductOxygen();

      // Verify immediate local state deduction
      expect(notifier.state.value?.oxygen, equals(4));
      // Verify pearls remain untouched
      expect(notifier.state.value?.pearls, equals(80));
      // Verify server dispatch occurred
      expect(fakeRepo.deductCallCount, equals(1));

      // Verify Tier-2 cache persistence
      final cachedStatus = await CacheService().getCachedStatus();
      expect(cachedStatus, isNotNull);
      expect(cachedStatus!.oxygen, equals(4));
    });

    test('supports sequential deductions across multiple mistakes (5 -> 4 -> 3 -> 2 -> 1 -> 0)', () async {
      final fakeRepo = FakeGamificationRepository(
        currentStatus: const GamificationStatusModel(oxygen: 5),
      );

      final notifier = GamificationStatusNotifier(fakeRepo);
      await notifier.refresh();

      for (int expectedOxygen = 4; expectedOxygen >= 0; expectedOxygen--) {
        notifier.deductOxygen();
        expect(notifier.state.value?.oxygen, equals(expectedOxygen));
      }

      expect(fakeRepo.deductCallCount, equals(5));
      final cachedStatus = await CacheService().getCachedStatus();
      expect(cachedStatus?.oxygen, equals(0));
    });

    test('enforces floor at 0: does not decrement into negative oxygen', () async {
      await CacheService().saveStatus(const GamificationStatusModel(oxygen: 0));
      final fakeRepo = FakeGamificationRepository(
        currentStatus: const GamificationStatusModel(oxygen: 0),
      );

      final notifier = GamificationStatusNotifier(fakeRepo);
      await notifier.refresh();

      expect(notifier.state.value?.oxygen, equals(0));

      // Deduct when already at 0
      notifier.deductOxygen();

      expect(notifier.state.value?.oxygen, equals(0));
      // Server is still notified of mistake
      expect(fakeRepo.deductCallCount, equals(1));

      final cachedStatus = await CacheService().getCachedStatus();
      expect(cachedStatus?.oxygen, equals(0));
    });

    test('handles server network failure gracefully without crashing or throwing', () async {
      final fakeRepo = FakeGamificationRepository(
        currentStatus: const GamificationStatusModel(oxygen: 3),
      );
      fakeRepo.shouldThrowDeduct = true;

      final notifier = GamificationStatusNotifier(fakeRepo);
      await notifier.refresh();

      expect(notifier.state.value?.oxygen, equals(3));

      // Should not throw even when repo.deductOxygen throws an exception
      expect(() => notifier.deductOxygen(), returnsNormally);

      // Optimistic decrement was still preserved for smooth gameplay
      expect(notifier.state.value?.oxygen, equals(2));
      expect(fakeRepo.deductCallCount, equals(1));
    });

    test('integrates with Riverpod ProviderContainer and updates listeners', () async {
      final fakeRepo = FakeGamificationRepository(
        currentStatus: const GamificationStatusModel(oxygen: 4),
      );

      final container = ProviderContainer(
        overrides: [
          gamificationRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      // Read notifier
      final notifier = container.read(gamificationStatusProvider.notifier);
      await notifier.refresh();

      expect(container.read(gamificationStatusProvider).value?.oxygen, equals(4));

      // Call deduct
      notifier.deductOxygen();

      // Verify provider state updated
      expect(container.read(gamificationStatusProvider).value?.oxygen, equals(3));
      expect(fakeRepo.deductCallCount, equals(1));
    });
  });
}
