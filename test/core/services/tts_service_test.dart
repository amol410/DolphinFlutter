import 'dart:io';
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

    test('getCacheKey is versioned, case-insensitive and formats v{ver}_locale_word', () {
      final version = TtsService.cacheVersion;
      expect(tts.getCacheKeyForTesting('Guten', 'de-DE'), 'v${version}_de-de_guten');
      expect(tts.getCacheKeyForTesting('hello', 'en-US'), 'v${version}_en-us_hello');
      expect(tts.getCacheKeyForTesting('WASSER', 'DE-DE'), 'v${version}_de-de_wasser');
    });

    test('getFileNameForWord generates versioned deterministic safe file names', () {
      final version = TtsService.cacheVersion;
      final name1 = tts.getFileNameForWordForTesting('Guten Tag', 'de-DE');
      final name2 = tts.getFileNameForWordForTesting('Guten Tag', 'de-DE');
      expect(name1, equals(name2));
      expect(name1.startsWith('tts_v${version}_de_de_'), isTrue);
      expect(name1.endsWith('.wav'), isTrue);

      final nameEn = tts.getFileNameForWordForTesting('Apple', 'en-US');
      expect(nameEn.startsWith('tts_v${version}_en_us_'), isTrue);
    });

    test('activeLocale switches between English (en-US) and German (de-DE)', () async {
      await tts.setLanguage('de');
      expect(tts.activeLocale, 'de-DE');
      expect(tts.currentLanguageCode, 'de');

      await tts.setLanguage('en');
      expect(tts.activeLocale, 'en-US');
      expect(tts.currentLanguageCode, 'en');
    });

    group('Android Google TTS Male Voice Matching', () {
      test('selects known high quality Google male voice over female voice', () {
        final mockVoices = [
          {
            "name": "en-us-x-sfd-local",
            "locale": "en-US",
            "features": "[female, notInstalled]",
          },
          {
            "name": "en-us-x-iom-local",
            "locale": "en-US",
            "features": "[male, notInstalled]",
          },
          {
            "name": "en-gb-x-rjd-local",
            "locale": "en-GB",
            "features": "[male, notInstalled]",
          },
        ];

        final selected = tts.selectBestVoiceForLocale(mockVoices, 'en-US');
        expect(selected, isNotNull);
        expect(selected!['name'], 'en-us-x-iom-local');
        expect(selected['locale'], 'en-US');
      });

      test('excludes female voices completely and returns null if only female available', () {
        final mockVoices = [
          {
            "name": "en-us-x-sfd-local",
            "locale": "en-US",
            "features": "[female]",
          },
          {
            "name": "en-us-language-female",
            "locale": "en-US",
            "features": "female",
          },
        ];

        final selected = tts.selectBestVoiceForLocale(mockVoices, 'en-US');
        expect(selected, isNull);
      });

      test('identifies male voice by features string even if name is generic', () {
        final mockVoices = [
          {
            "name": "generic-voice-1",
            "locale": "en-US",
            "features": "[female]",
          },
          {
            "name": "generic-voice-2",
            "locale": "en-US",
            "features": "[male, notInstalled]",
          },
        ];

        final selected = tts.selectBestVoiceForLocale(mockVoices, 'en-US');
        expect(selected, isNotNull);
        expect(selected!['name'], 'generic-voice-2');
      });

      test('never falls back to first voice when first voice is female', () {
        final mockVoices = [
          {
            "name": "en-us-first-female",
            "locale": "en-US",
            "features": "[female]",
          },
          {
            "name": "en-us-second-neutral",
            "locale": "en-US",
            "features": "[neutral]",
          },
        ];

        final selected = tts.selectBestVoiceForLocale(mockVoices, 'en-US');
        expect(selected, isNotNull);
        // Must select the neutral non-female voice, NEVER the female first voice!
        expect(selected!['name'], 'en-us-second-neutral');
      });

      test('correctly identifies iOS / macOS male voices like Daniel, Oliver, David', () {
        final mockVoices = [
          {
            "name": "com.apple.voice.compact.en-GB.Daniel",
            "locale": "en-GB",
          },
          {
            "name": "com.apple.voice.compact.en-GB.Martha",
            "locale": "en-GB",
            "gender": "female",
          },
        ];

        final selected = tts.selectBestVoiceForLocale(mockVoices, 'en-US');
        expect(selected, isNotNull);
        expect(selected!['name'], contains('Daniel'));
      });
    });

    group('Cache Wiping & Invalidation', () {
      test('cleanStaleCache removes unversioned and old version files while preserving current cache version', () async {
        final tempDir = await Directory.systemTemp.createTemp('tts_cache_test_');
        try {
          final staleUnversioned = File('${tempDir.path}/tts_en_us_hello_abc123.wav');
          await staleUnversioned.writeAsString('old audio');

          final staleV1 = File('${tempDir.path}/tts_v1_en_us_cat_def456.wav');
          await staleV1.writeAsString('v1 audio');

          final currentV2 = File('${tempDir.path}/tts_v${TtsService.cacheVersion}_en_us_dog_789ghi.wav');
          await currentV2.writeAsString('v2 audio');

          final unrelatedFile = File('${tempDir.path}/notes.txt');
          await unrelatedFile.writeAsString('keep me');

          expect(await staleUnversioned.exists(), isTrue);
          expect(await staleV1.exists(), isTrue);
          expect(await currentV2.exists(), isTrue);
          expect(await unrelatedFile.exists(), isTrue);

          await tts.cleanStaleCacheForTesting(tempDir);

          // Stale files should be deleted
          expect(await staleUnversioned.exists(), isFalse);
          expect(await staleV1.exists(), isFalse);

          // Current versioned file and unrelated files should be preserved
          expect(await currentV2.exists(), isTrue);
          expect(await unrelatedFile.exists(), isTrue);
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    });
  });
}
