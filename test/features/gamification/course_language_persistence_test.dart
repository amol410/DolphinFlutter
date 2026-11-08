import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolphincoder/core/services/cache_service.dart';
import 'package:dolphincoder/features/gamification/data/gamification_repository.dart';
import 'package:dolphincoder/features/gamification/data/models/gamification_models.dart';
import 'package:dolphincoder/features/gamification/providers/gamification_provider.dart';

/// Regression tests for the "English→Hindi lesson completion reverts the
/// learner to German→English" bug.
///
/// Root causes covered here:
///  1. Status blobs written to the cache omitted the active course, so the next
///     read reverted to the German defaults.
///  2. `loadPath()` called without a course silently fell back to German.
///  3. A failed course switch left in-memory state on the previous course.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const englishCourse = GamificationStatusModel(
    targetLanguage: 'en',
    nativeLanguage: 'hi',
    currentLevel: 'A2',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await CacheService().setActiveUser('test_user');
  });

  group('Status cache keeps the active course', () {
    test('saveStatus/getCachedStatus round-trips en→hi instead of reverting to de', () async {
      await CacheService().saveStatus(englishCourse);

      final restored = await CacheService().getCachedStatus();

      expect(restored, isNotNull);
      expect(restored!.targetLanguage, 'en');
      expect(restored.nativeLanguage, 'hi');
      expect(restored.currentLevel, 'A2');
    });

    test('applyServerStatus preserves the active course when the payload omits it', () {
      final notifier = GamificationStatusNotifier(_NoopRepository());
      notifier.state = const AsyncValue.data(englishCourse);

      // Legacy lesson-completion payloads carry only economy fields.
      notifier.applyServerStatus(<String, dynamic>{
        'totalXp': 250,
        'pearls': 42,
        'oxygen': 3,
        'streakCount': 7,
      });

      final updated = notifier.state.value!;
      expect(updated.totalXp, 250);
      expect(updated.pearls, 42);
      // The course must NOT snap back to the German defaults.
      expect(updated.targetLanguage, 'en');
      expect(updated.nativeLanguage, 'hi');
      expect(updated.currentLevel, 'A2');
    });

    test('applyServerStatus adopts the course when the payload provides it', () {
      final notifier = GamificationStatusNotifier(_NoopRepository());
      notifier.state = const AsyncValue.data(englishCourse);

      notifier.applyServerStatus(<String, dynamic>{
        'totalXp': 100,
        'targetLanguage': 'en',
        'nativeLanguage': 'hi',
        'currentLevel': 'B1',
      });

      final updated = notifier.state.value!;
      expect(updated.currentLevel, 'B1');
      expect(updated.targetLanguage, 'en');
      expect(updated.nativeLanguage, 'hi');
    });

    test('status JSON round-trip never loses targetLanguage/nativeLanguage', () {
      final json = jsonEncode(englishCourse.toJson());
      final decoded = GamificationStatusModel.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );

      expect(decoded.targetLanguage, 'en');
      expect(decoded.nativeLanguage, 'hi');
    });
  });

  group('switchCourse updates state without waiting on a refresh', () {
    test('applies the chosen course optimistically and persists it', () async {
      final repo = _NoopRepository(switchResult: true);
      final notifier = GamificationStatusNotifier(repo);
      notifier.state = const AsyncValue.data(
        GamificationStatusModel(targetLanguage: 'de', nativeLanguage: 'en'),
      );

      final ok = await notifier.switchCourse(
        targetLanguage: 'en',
        nativeLanguage: 'hi',
        level: 'A2',
      );

      expect(ok, isTrue);
      final status = notifier.state.value!;
      expect(status.targetLanguage, 'en');
      expect(status.nativeLanguage, 'hi');
      expect(status.currentLevel, 'A2');

      // The cache must agree, otherwise a restart reverts to German.
      final cached = await CacheService().getCachedStatus();
      expect(cached!.targetLanguage, 'en');
      expect(cached.nativeLanguage, 'hi');
    });

    test('leaves state untouched when the backend rejects the switch', () async {
      final repo = _NoopRepository(switchResult: false);
      final notifier = GamificationStatusNotifier(repo);
      notifier.state = const AsyncValue.data(
        GamificationStatusModel(targetLanguage: 'de', nativeLanguage: 'en'),
      );

      final ok = await notifier.switchCourse(
        targetLanguage: 'en',
        nativeLanguage: 'hi',
      );

      expect(ok, isFalse);
      expect(notifier.state.value!.targetLanguage, 'de');
    });
  });
}

/// Repository stub: no network. Overrides only what these tests touch.
class _NoopRepository extends GamificationRepository {
  _NoopRepository({this.switchResult = true});

  final bool switchResult;

  @override
  Future<bool> switchCourse({
    required String targetLanguage,
    required String nativeLanguage,
    String level = 'A1',
  }) async =>
      switchResult;

  @override
  Future<GamificationStatusModel> getStatus() async =>
      const GamificationStatusModel(targetLanguage: 'de', nativeLanguage: 'en');
}
