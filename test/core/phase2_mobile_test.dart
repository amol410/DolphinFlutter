import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolphincoder/core/constants/api_constants.dart';
import 'package:dolphincoder/core/network/dio_client.dart';
import 'package:dolphincoder/features/gamification/data/gamification_repository.dart';
import 'package:dolphincoder/features/gamification/data/models/gamification_models.dart';
import 'package:dolphincoder/features/gamification/providers/gamification_provider.dart';

/// Custom Mock HTTP Adapter for intercepting Dio network requests.
class MockPhase2Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  MockPhase2Adapter(this.onFetch);

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

/// Fake GamificationRepository for testing notifiers in complete isolation
class FakeGamificationRepositoryPhase2 extends GamificationRepository {
  GamificationStatusModel currentStatus;
  int buyStreakFreezeCalls = 0;
  int buyDoubleXpCalls = 0;
  List<QuestModel> mockQuests;

  FakeGamificationRepositoryPhase2({
    this.currentStatus = const GamificationStatusModel(
      oxygen: 5,
      pearls: 200,
      streakFreezeCount: 0,
      isDoubleXpActive: false,
    ),
    this.mockQuests = const [],
  });

  @override
  Future<GamificationStatusModel> getStatus() async {
    return currentStatus;
  }

  @override
  Future<Map<String, dynamic>> buyStreakFreeze() async {
    buyStreakFreezeCalls++;
    currentStatus = GamificationStatusModel(
      oxygen: currentStatus.oxygen,
      pearls: currentStatus.pearls - 100,
      streakFreezeCount: currentStatus.streakFreezeCount + 1,
      isDoubleXpActive: currentStatus.isDoubleXpActive,
    );
    return {
      'success': true,
      'message': 'Streak Freeze acquired!',
      'pearls': currentStatus.pearls,
      'streakFreezeCount': currentStatus.streakFreezeCount,
    };
  }

  @override
  Future<Map<String, dynamic>> buyDoubleXp() async {
    buyDoubleXpCalls++;
    currentStatus = GamificationStatusModel(
      oxygen: currentStatus.oxygen,
      pearls: currentStatus.pearls - 150,
      streakFreezeCount: currentStatus.streakFreezeCount,
      isDoubleXpActive: true,
      doubleXpExpiresAt: DateTime.now().add(const Duration(minutes: 30)).toIso8601String(),
    );
    return {
      'success': true,
      'message': 'Double XP Potion activated!',
      'pearls': currentStatus.pearls,
      'isDoubleXpActive': true,
    };
  }

  @override
  Future<List<QuestModel>> getQuests() async {
    return mockQuests;
  }

  @override
  Future<Map<String, dynamic>> claimQuest(dynamic questId) async {
    mockQuests = mockQuests.map((q) => q.id == questId ? q.copyWith(isClaimed: true) : q).toList();
    return {
      'success': true,
      'message': 'Reward claimed!',
      'pearls': currentStatus.pearls + 25,
      'totalXp': currentStatus.totalXp + 30,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 2 Gamification Models & Deserialization Tests', () {
    test('GamificationStatusModel parses streakFreezeCount and double XP fields', () {
      final json = {
        'oxygen': 4,
        'maxOxygen': 5,
        'secondsUntilNextRefill': 600,
        'pearls': 250,
        'totalXp': 1200,
        'streakCount': 7,
        'longestStreak': 14,
        'streakFreezeCount': 2,
        'isDoubleXpActive': true,
        'doubleXpExpiresAt': '2026-11-01T12:00:00.000Z',
      };

      final model = GamificationStatusModel.fromJson(json);
      expect(model.oxygen, 4);
      expect(model.pearls, 250);
      expect(model.streakFreezeCount, 2);
      expect(model.isDoubleXpActive, true);
      expect(model.doubleXpExpiresAt, isNotNull);
    });

    test('QuestModel parses fields and calculates progress percentage correctly', () {
      final json = {
        'id': 'quest_101',
        'title': 'Earn 30 XP in lessons',
        'type': 'xp',
        'current': 15,
        'target': 30,
        'rewardPearls': 15,
        'rewardXp': 20,
        'isCompleted': false,
        'isClaimed': false,
      };

      final quest = QuestModel.fromJson(json);
      expect(quest.id, 0); // fallback parsed int
      expect(quest.title, 'Earn 30 XP in lessons');
      expect(quest.type, 'xp');
      expect(quest.current, 15);
      expect(quest.target, 30);
      expect(quest.rewardPearls, 15);
      expect(quest.rewardXp, 20);
      expect(quest.isCompleted, false);
      expect(quest.isClaimed, false);
      expect(quest.progressPct, 0.5); // 15 / 30 = 0.5
    });

    test('QuestModel clamps progress percentage between 0.0 and 1.0', () {
      final overachieved = QuestModel.fromJson({
        'id': 102,
        'title': 'Complete 1 lesson',
        'type': 'lesson',
        'current': 5,
        'target': 1,
        'rewardPearls': 10,
        'rewardXp': 10,
        'isCompleted': true,
        'isClaimed': false,
      });
      expect(overachieved.progressPct, 1.0);

      final zeroTarget = QuestModel.fromJson({
        'id': 103,
        'title': 'Empty quest',
        'type': 'lesson',
        'current': 0,
        'target': 0,
        'rewardPearls': 0,
        'rewardXp': 0,
        'isCompleted': true,
        'isClaimed': false,
      });
      expect(zeroTarget.progressPct, 1.0);
    });
  });

  group('Phase 2 GamificationRepository HTTP Requests Tests', () {
    test('buyStreakFreeze sends POST /gamification/shop/buy-streak-freeze and deserializes response', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockPhase2Adapter((options) async {
        expect(options.path, ApiConstants.gamificationBuyStreakFreeze);
        expect(options.method, 'POST');

        final payload = jsonEncode({
          'success': true,
          'message': 'Streak Freeze acquired! Your streak is now protected.',
          'pearls': 150,
          'streakFreezeCount': 2,
        });

        return ResponseBody.fromString(
          payload,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      final res = await repo.buyStreakFreeze();

      expect(res['success'], true);
      expect(res['pearls'], 150);
      expect(res['streakFreezeCount'], 2);
    });

    test('buyDoubleXp sends POST /gamification/shop/buy-double-xp and deserializes response', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockPhase2Adapter((options) async {
        expect(options.path, ApiConstants.gamificationBuyDoubleXp);
        expect(options.method, 'POST');

        final payload = jsonEncode({
          'success': true,
          'message': 'Double XP Potion activated for 30 minutes!',
          'pearls': 50,
          'isDoubleXpActive': true,
          'doubleXpExpiresAt': '2026-11-01T02:30:00.000Z',
        });

        return ResponseBody.fromString(
          payload,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      final res = await repo.buyDoubleXp();

      expect(res['success'], true);
      expect(res['pearls'], 50);
      expect(res['isDoubleXpActive'], true);
    });

    test('getQuests sends GET /gamification/quests and deserializes list', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockPhase2Adapter((options) async {
        expect(options.path, ApiConstants.gamificationQuests);
        expect(options.method, 'GET');

        final payload = jsonEncode({
          'success': true,
          'quests': [
            {
              'id': 1,
              'title': 'Earn 30 XP in lessons',
              'type': 'xp',
              'current': 12,
              'target': 30,
              'rewardPearls': 15,
              'rewardXp': 20,
              'isCompleted': false,
              'isClaimed': false,
            },
            {
              'id': 2,
              'title': 'Practice 1 Sprechen pronunciation test',
              'type': 'speech',
              'current': 1,
              'target': 1,
              'rewardPearls': 25,
              'rewardXp': 30,
              'isCompleted': true,
              'isClaimed': false,
            }
          ],
        });

        return ResponseBody.fromString(
          payload,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      final quests = await repo.getQuests();

      expect(quests.length, 2);
      expect(quests[0].title, 'Earn 30 XP in lessons');
      expect(quests[0].isCompleted, false);
      expect(quests[1].title, 'Practice 1 Sprechen pronunciation test');
      expect(quests[1].isCompleted, true);
    });

    test('claimQuest sends POST /gamification/claim-quest with questId payload', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockPhase2Adapter((options) async {
        expect(options.path, ApiConstants.gamificationClaimQuest);
        expect(options.method, 'POST');
        expect(options.data['questId'], 2);

        final payload = jsonEncode({
          'success': true,
          'message': 'Reward claimed!',
          'pearls': 125,
          'totalXp': 330,
          'rewardPearls': 25,
          'rewardXp': 30,
        });

        return ResponseBody.fromString(
          payload,
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      final res = await repo.claimQuest(2);

      expect(res['success'], true);
      expect(res['pearls'], 125);
      expect(res['rewardPearls'], 25);
    });
  });

  group('Phase 2 StateNotifier Integration Tests', () {
    test('GamificationStatusNotifier buyStreakFreeze updates state synchronously on success', () async {
      final fakeRepo = FakeGamificationRepositoryPhase2(
        currentStatus: const GamificationStatusModel(
          oxygen: 5,
          pearls: 200,
          streakFreezeCount: 0,
        ),
      );

      final notifier = GamificationStatusNotifier(fakeRepo);
      await notifier.refresh();
      expect(notifier.state.value?.pearls, 200);
      expect(notifier.state.value?.streakFreezeCount, 0);

      // Perform buyStreakFreeze
      final res = await notifier.buyStreakFreeze();
      expect(res['success'], true);

      // Check updated notifier state
      expect(notifier.state.value?.pearls, 100);
      expect(notifier.state.value?.streakFreezeCount, 1);
      expect(fakeRepo.buyStreakFreezeCalls, 1);
    });

    test('GamificationStatusNotifier buyDoubleXp updates state synchronously on success', () async {
      final fakeRepo = FakeGamificationRepositoryPhase2(
        currentStatus: const GamificationStatusModel(
          oxygen: 5,
          pearls: 300,
          streakFreezeCount: 0,
          isDoubleXpActive: false,
        ),
      );

      final notifier = GamificationStatusNotifier(fakeRepo);
      await notifier.refresh();
      expect(notifier.state.value?.pearls, 300);

      final res = await notifier.buyDoubleXp();
      expect(res['success'], true);

      expect(notifier.state.value?.pearls, 150);
      expect(notifier.state.value?.isDoubleXpActive, true);
      expect(fakeRepo.buyDoubleXpCalls, 1);
    });

    test('questsProvider loads and updates claimed state when claimQuest is called', () async {
      final mockQuests = [
        const QuestModel(
          id: 10,
          title: 'Speak 1 German Word',
          type: 'speech',
          current: 1,
          target: 1,
          rewardPearls: 25,
          rewardXp: 30,
          isCompleted: true,
          isClaimed: false,
        ),
      ];

      final fakeRepo = FakeGamificationRepositoryPhase2(
        mockQuests: mockQuests,
      );

      final container = ProviderContainer(
        overrides: [
          gamificationRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      // Await quests load
      await container.read(questsProvider.notifier).loadQuests();
      final quests = container.read(questsProvider).value;
      expect(quests, isNotNull);
      expect(quests!.length, 1);
      expect(quests.first.isClaimed, false);

      // Claim quest
      final res = await container.read(questsProvider.notifier).claimQuest(10);
      expect(res['success'], true);

      // Verify quest in state is marked isClaimed = true
      final updatedQuests = container.read(questsProvider).value;
      expect(updatedQuests?.first.isClaimed, true);
    });
  });
}
