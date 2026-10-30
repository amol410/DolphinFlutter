import 'package:flutter_test/flutter_test.dart';
import 'package:dolphincoder/core/services/analytics_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AnalyticsService Unit Tests', () {
    test('AnalyticsService returns a singleton instance', () {
      final instance1 = AnalyticsService();
      final instance2 = AnalyticsService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('Gracefully handles uninitialized logging without crashing', () async {
      final service = AnalyticsService();
      // Should not throw even before Firebase is initialized in tests
      await service.logEvent(name: 'test_event', parameters: {'test_key': 'test_val'});
      await service.logLessonCompleted(lessonId: 'lesson_1', stageType: 'word_match', score: 100);
      await service.logAdRewardClaimed(rewardType: 'oxygen', amount: 2);
      await service.setUserIdentifier('user_123');
      await service.recordNonFatalError(Exception('Test error'), StackTrace.empty);
    });
  });
}
