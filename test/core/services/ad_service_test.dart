import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dolphincoder/core/services/ad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AdService Lesson Cadence Tests', () {
    test('Initial lesson count is 0 and shouldShowLessonInterstitial is false', () async {
      final adService = AdService();
      await adService.resetLessonCount();
      final count = await adService.getLessonCount();
      expect(count, 0);

      final shouldShow = await adService.shouldShowLessonInterstitial();
      expect(shouldShow, isFalse);
    });

    test('Incrementing lesson count updates counter and triggers eligibility at threshold', () async {
      final adService = AdService();
      await adService.resetLessonCount();

      int count = await adService.incrementLessonCount();
      expect(count, 1);
      expect(await adService.shouldShowLessonInterstitial(), isFalse);

      count = await adService.incrementLessonCount();
      expect(count, 2);
      expect(await adService.shouldShowLessonInterstitial(), isFalse);

      count = await adService.incrementLessonCount();
      expect(count, 3);
      expect(await adService.shouldShowLessonInterstitial(), isTrue);
    });

    test('Resetting lesson count returns counter back to 0', () async {
      final adService = AdService();
      await adService.resetLessonCount();
      await adService.incrementLessonCount();
      await adService.incrementLessonCount();
      await adService.incrementLessonCount();
      expect(await adService.shouldShowLessonInterstitial(), isTrue);

      await adService.resetLessonCount();
      expect(await adService.getLessonCount(), 0);
      expect(await adService.shouldShowLessonInterstitial(), isFalse);
    });

    test('showInterstitialIfEligible calls onDone immediately when ineligible', () async {
      final adService = AdService();
      await adService.resetLessonCount();

      bool doneCalled = false;
      await adService.showInterstitialIfEligible(onDone: () {
        doneCalled = true;
      });

      expect(doneCalled, isTrue);
    });

    test('showInterstitialIfEligible calls onDone when eligible but ad not loaded', () async {
      final adService = AdService();
      await adService.resetLessonCount();
      await adService.incrementLessonCount();
      await adService.incrementLessonCount();

      bool doneCalled = false;
      await adService.showInterstitialIfEligible(onDone: () {
        doneCalled = true;
      });

      expect(doneCalled, isTrue);
    });
  });
}
