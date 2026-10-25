import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphincoder/core/services/tts_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TtsService tts;

  setUpAll(() {
    const channel1 = MethodChannel('xyz.luan/audioplayers.global');
    const channel2 = MethodChannel('xyz.luan/audioplayers');
    const channel3 = MethodChannel('flutter_tts');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel1, (MethodCall methodCall) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel2, (MethodCall methodCall) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel3, (MethodCall methodCall) async => 1);

    tts = TtsService();
  });

  group('TtsService Unit Tests', () {

    test('normalizeWord removes leading and trailing punctuation', () {
      expect(tts.normalizeWordForTesting('Hello,'), 'Hello');
      expect(tts.normalizeWordForTesting('"Guten Tag!"'), 'Guten Tag');
      expect(tts.normalizeWordForTesting('...Wasser?'), 'Wasser');
      expect(tts.normalizeWordForTesting('  Apfel  '), 'Apfel');
      expect(tts.normalizeWordForTesting('„Brot“'), 'Brot');
    });

    test('getCacheKey is case-insensitive and formats locale_word', () {
      expect(tts.getCacheKeyForTesting('Guten', 'de-DE'), 'de-de_guten');
      expect(tts.getCacheKeyForTesting('hello', 'en-GB'), 'en-gb_hello');
      expect(tts.getCacheKeyForTesting('WASSER', 'DE-DE'), 'de-de_wasser');
    });

    test('getFileNameForWord generates deterministic safe file names', () {
      final name1 = tts.getFileNameForWordForTesting('Guten Tag', 'de-DE');
      final name2 = tts.getFileNameForWordForTesting('Guten Tag', 'de-DE');
      expect(name1, equals(name2));
      expect(name1.startsWith('tts_de_de_'), isTrue);
      expect(name1.endsWith('.wav'), isTrue);
    });

    test('activeLocale switches between British English and German', () {
      tts.setLanguage('de');
      expect(tts.activeLocale, 'de-DE');
      expect(tts.currentLanguageCode, 'de');

      tts.setLanguage('en');
      expect(tts.activeLocale, 'en-GB');
      expect(tts.currentLanguageCode, 'en');
    });
  });
}
