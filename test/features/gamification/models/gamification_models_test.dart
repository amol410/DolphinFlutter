import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dolphincoder/core/network/dio_client.dart';
import 'package:dolphincoder/features/gamification/data/gamification_repository.dart';
import 'package:dolphincoder/features/gamification/data/models/gamification_models.dart';
import 'package:dolphincoder/features/gamification/providers/gamification_provider.dart';

class _FakeWindowedGamificationRepository extends GamificationRepository {
  @override
  Future<GamificationStatusModel> getStatus() async {
    return const GamificationStatusModel(
      pearls: 100,
      oxygen: 5,
      totalXp: 38,
      targetLanguage: 'de',
      nativeLanguage: 'en',
      currentLevel: 'A1',
    );
  }

  @override
  Future<List<PathNodeModel>> getPath({
    String? targetLanguage,
    String? nativeLanguage,
    String? level,
    int? section,
    int? unit,
    int? startUnit,
    int? endUnit,
  }) async {
    return const [
      PathNodeModel(
        id: 501,
        index: 5,
        title: 'Unit 2 Lesson 1',
        subtitle: 'Windowed Node 5',
        type: 'lesson',
        status: 'available',
        unitNumber: 2,
      ),
      PathNodeModel(
        id: 502,
        index: 6,
        title: 'Unit 2 Lesson 2',
        subtitle: 'Windowed Node 6',
        type: 'lesson',
        status: 'locked',
        unitNumber: 2,
      ),
    ];
  }

  @override
  Future<Map<String, dynamic>> completeNode({
    required int nodeIndex,
    int scorePct = 100,
    int? stars,
    int? xpEarned,
    int? pearlsEarned,
    String? attemptId,
    String? targetLanguage,
    String? nativeLanguage,
    String? level,
  }) async {
    return {
      'success': true,
      'stars': 3,
      'scorePct': scorePct,
      'pearls': 110,
      'oxygen': 5,
      'totalXp': 50,
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DioClient.reset();
    DioClient.setToken('test-token');
  });

  group('GamificationStatusModel Tests', () {
    test('fromJson parses full JSON payload correctly', () {
      final json = {
        'streakCount': 5,
        'longestStreak': 12,
        'lastActiveDate': '2026-10-25',
        'dailyTargetXp': 30,
        'targetLanguage': 'de',
        'nativeLanguage': 'en',
        'currentLevel': 'A1',
        'pearls': 150,
        'oxygen': 4,
        'totalXp': 450,
        'currentLeague': 'Sapphire Bay',
      };

      final model = GamificationStatusModel.fromJson(json);

      expect(model.streakCount, 5);
      expect(model.longestStreak, 12);
      expect(model.lastActiveDate, '2026-10-25');
      expect(model.pearls, 150);
      expect(model.oxygen, 4);
      expect(model.totalXp, 450);
      expect(model.currentLeague, 'Sapphire Bay');
    });

    test('toJson serializes model back to Map', () {
      const model = GamificationStatusModel(
        streakCount: 3,
        longestStreak: 7,
        lastActiveDate: '2026-10-24',
        pearls: 80,
        oxygen: 5,
        totalXp: 210,
      );

      final json = model.toJson();
      expect(json['streakCount'], 3);
      expect(json['pearls'], 80);
      expect(json['oxygen'], 5);
      expect(json['totalXp'], 210);
    });

    test('copyWith updates specified fields only', () {
      const model = GamificationStatusModel(pearls: 50, oxygen: 3);
      final updated = model.copyWith(oxygen: 5, pearls: 75);

      expect(updated.oxygen, 5);
      expect(updated.pearls, 75);
      expect(updated.streakCount, model.streakCount);
    });
  });

  group('PathNodeModel Tests', () {
    test('fromJson parses node correctly with fallback defaults', () {
      final json = {
        'index': 0,
        'title': 'Grundlagen & Begrüßung',
        'subtitle': 'Essential Greetings',
        'type': 'lesson',
        'status': 'available',
        'xpReward': 10,
        'pearlsReward': 1,
      };

      final node = PathNodeModel.fromJson(json);

      expect(node.index, 0);
      expect(node.title, 'Grundlagen & Begrüßung');
      expect(node.type, 'lesson');
      expect(node.status, 'available');
      expect(node.xpReward, 10);
      expect(node.pearlsReward, 1);
    });

    test('copyWith produces modified copy', () {
      const node = PathNodeModel(
        index: 1,
        title: 'Karaoke Node',
        subtitle: 'Sing along',
        type: 'karaoke',
        status: 'locked',
      );

      final completed = node.copyWith(status: 'completed', stars: 3);

      expect(completed.status, 'completed');
      expect(completed.stars, 3);
      expect(completed.title, node.title);
    });

    test('PathNodesNotifier.completeNode matches by node.index on windowed slices', () async {
      final container = ProviderContainer(
        overrides: [
          gamificationRepositoryProvider.overrideWithValue(_FakeWindowedGamificationRepository()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(pathNodesProvider.notifier);
      // Allow constructor _initPath() microtasks to settle before interacting
      await Future<void>.delayed(const Duration(milliseconds: 50));
      await notifier.loadPath(startUnit: 2, endUnit: 2);

      await notifier.completeNode(5, scorePct: 100, attemptId: 'att-win-5');
      final updatedNodes = container.read(pathNodesProvider).value!;
      expect(updatedNodes[0].index, 5);
      expect(updatedNodes[0].status, 'completed');
      expect(updatedNodes[0].stars, 3);
      expect(updatedNodes[1].index, 6);
      expect(updatedNodes[1].status, 'available');
    });
  });
}
