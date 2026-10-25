import 'package:flutter_test/flutter_test.dart';
import 'package:dolphincoder/features/gamification/data/models/gamification_models.dart';

void main() {
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
  });
}
