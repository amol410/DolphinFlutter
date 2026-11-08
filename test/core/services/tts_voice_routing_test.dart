import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dolphincoder/core/services/tts_service.dart';

/// Regression tests for "English text must always be spoken by the English voice".
///
/// The bug: in an English→Hindi course, both English and Hindi text were sent to
/// a single `en-US` voice. Devanagari then resolved through the platform's
/// script-fallback, which picked a different voice per word — so words randomly
/// alternated between a male and a female speaker.
void main() {
  // Required before the TtsService singleton constructs its MethodChannels.
  TestWidgetsFlutterBinding.ensureInitialized();

  late TtsService service;

  setUpAll(() {
    // Same channel mocks the existing TtsService suite uses.
    const channel1 = MethodChannel('xyz.luan/audioplayers.global');
    const channel2 = MethodChannel('xyz.luan/audioplayers');
    const channel3 = MethodChannel('flutter_tts');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel1, (MethodCall call) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel2, (MethodCall call) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel3, (MethodCall call) async => 1);

    service = TtsService();
  });

  group('English text resolves to the English voice', () {

    test('plain English words use en-US', () {
      for (final word in <String>['water', 'Hello', 'the', 'book', 'run']) {
        expect(
          service.localeForTextForTesting(word),
          'en-US',
          reason: '"$word" must be spoken by the English voice',
        );
      }
    });

    test('English sentences with punctuation use en-US', () {
      for (final text in <String>[
        'I drink water.',
        'Where is the station?',
        "It's a beautiful day!",
      ]) {
        expect(service.localeForTextForTesting(text), 'en-US');
      }
    });

    test('mixed English/Devanagari text still uses the English voice', () {
      // Only text that is predominantly native script should switch voices;
      // a single embedded native word must not hijack an English sentence.
      expect(service.localeForTextForTesting('I drink water (पानी)'), 'en-US');
      expect(service.localeForTextForTesting('Hello पानी'), 'en-US');
    });
  });

  group('Hindi/Marathi text resolves to the native voice', () {


    test('Devanagari words use the Hindi native voice', () {
      for (final word in <String>['पानी', 'लड़का', 'किताब', 'धन्यवाद']) {
        expect(
          service.localeForTextForTesting(word),
          'hi-IN',
          reason: '"$word" is Hindi and must not be spoken by the English voice',
        );
      }
    });

    test('the native and English locales are always different', () {
      // The core invariant: one voice per language, never shared.
      expect(
        service.localeForTextForTesting('water'),
        isNot(service.localeForTextForTesting('पानी')),
      );
    });
  });

  group('Word normalization handles Devanagari punctuation', () {


    test('danda and double-danda are stripped', () {
      expect(service.normalizeWordForTesting('पानी।'), 'पानी');
      expect(service.normalizeWordForTesting('पानी॥'), 'पानी');
      expect(service.normalizeWordForTesting('।पानी।'), 'पानी');
    });

    test('the same word with and without danda produces one cache key', () {
      final a = service.getCacheKeyForTesting(
        service.normalizeWordForTesting('पानी।'),
        'hi-IN',
      );
      final b = service.getCacheKeyForTesting(
        service.normalizeWordForTesting('पानी'),
        'hi-IN',
      );
      expect(a, b);
    });
  });

  group('Voice selection keeps genders separate per language', () {


    final voices = <Map<String, String>>[
      {'name': 'en-us-x-iom-local', 'locale': 'en-US', 'features': 'male'},
      {'name': 'en-us-x-sfg-local', 'locale': 'en-US', 'features': 'female'},
      {'name': 'hi-in-x-hia-local', 'locale': 'hi-IN', 'features': 'female'},
      {'name': 'hi-in-x-hid-local', 'locale': 'hi-IN', 'features': 'male'},
    ];

    test('English picks an English voice, never a Hindi one', () {
      final voice = service.selectBestVoiceForLocale(voices, 'en-US');
      expect(voice, isNotNull);
      expect(voice!['locale'], startsWith('en'));
    });

    test('Hindi picks a Hindi voice, never the English one', () {
      final voice = service.selectBestVoiceForLocale(voices, 'hi-IN');
      expect(voice, isNotNull);
      expect(voice!['locale'], startsWith('hi'));
    });

    test('Hindi prefers a male voice when one exists', () {
      final voice = service.selectBestVoiceForLocale(voices, 'hi-IN');
      expect(voice!['name'], contains('hid'));
    });
  });
}
