import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reusable Text-To-Speech Service
/// Supports British English (en-GB) and German (de-DE) pronunciation
/// with natural voices, proper accent phonetics, and zero-latency tactile dispatch.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  Future<void>? _initFuture;
  String _currentLanguageCode = 'en'; // default to en or de based on active course
  String get currentLanguageCode => _currentLanguageCode;

  String get activeLocale => _currentLanguageCode == 'en' ? 'en-GB' : 'de-DE';

  /// Update active learning language for speech synthesis ('en' for British English, 'de' for German)
  Future<void> setLanguage(String langCode) async {
    final cleaned = langCode.toLowerCase().trim();
    _currentLanguageCode = (cleaned == 'en' || cleaned == 'english') ? 'en' : 'de';
    
    if (!_isInitialized) {
      await init();
      return;
    }

    try {
      final locale = activeLocale;
      await _flutterTts.setLanguage(locale);
      await _applyBestVoiceForLocale(locale);
      debugPrint('🔊 [TtsService] Switched speech synthesis language to $locale');
    } catch (e) {
      debugPrint('⚠️ [TtsService] setLanguage error: $e');
    }
  }

  /// Thread-safe initialization.
  Future<void> init() {
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
    if (_isInitialized) return;
    try {
      final locale = activeLocale;
      await _flutterTts.setLanguage(locale);
      // Speaking rate: 0.48 for crystal-clear language learning articulation
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);
      // Pitch: 1.05 provides a natural, bright timbre
      await _flutterTts.setPitch(1.05);
      // Non-blocking asynchronous mode for instant tactile word taps
      await _flutterTts.awaitSpeakCompletion(false);

      await _applyBestVoiceForLocale(locale);

      _isInitialized = true;
      debugPrint('⚡ [TtsService] Engine initialized for $locale');
    } catch (e) {
      debugPrint('⚠️ [TtsService] Init error: $e');
    }
  }

  /// Automatically matches and binds the best natural voice for the target locale.
  /// For 'en-GB': selects British English female / natural accent (rjs, gda, fis, etc.)
  /// For 'de-DE': selects German female voice (anna, katja, eva, etc.)
  Future<void> _applyBestVoiceForLocale(String targetLocale) async {
    try {
      final dynamic rawVoices = await _flutterTts.getVoices.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => null,
      );

      if (rawVoices is! List) return;

      final isBritish = targetLocale.toLowerCase().contains('en-gb') ||
          targetLocale.toLowerCase().contains('en_gb');

      Map<String, String>? selectedVoice;

      for (final voice in rawVoices) {
        if (voice is! Map) continue;
        final name = (voice['name'] ?? '').toString().toLowerCase();
        final locale = (voice['locale'] ?? '').toString().toLowerCase();

        if (isBritish) {
          // Look for British English voices
          final isGbLocale = locale.contains('en-gb') || locale.contains('en_gb');
          if (!isGbLocale) continue;

          final isHighQualityFemale = name.contains('female') ||
              name.contains('rjs') ||
              name.contains('gda') ||
              name.contains('fis') ||
              name.contains('gba') ||
              name.contains('gb');

          if (isHighQualityFemale) {
            selectedVoice = {
              "name": voice['name'].toString(),
              "locale": voice['locale'].toString(),
            };
            break;
          }
          selectedVoice ??= {
            "name": voice['name'].toString(),
            "locale": voice['locale'].toString(),
          };
        } else {
          // Look for German voices
          final isDeLocale = locale.contains('de-de') || locale.contains('de_de');
          if (!isDeLocale) continue;

          final isFemale = name.contains('female') ||
              name.contains('frau') ||
              name.contains('w-') ||
              name.contains('eva') ||
              name.contains('marlene') ||
              name.contains('vicki') ||
              name.contains('anna') ||
              name.contains('katja') ||
              name.contains('de-de-x-deb') ||
              name.contains('de-de-x-dea') ||
              name.contains('de-de-x-deg') ||
              name.contains('de-de-x-def');

          if (isFemale) {
            selectedVoice = {
              "name": voice['name'].toString(),
              "locale": voice['locale'].toString(),
            };
            break;
          }
          selectedVoice ??= {
            "name": voice['name'].toString(),
            "locale": voice['locale'].toString(),
          };
        }
      }

      if (selectedVoice != null) {
        await _flutterTts.setVoice(selectedVoice);
        debugPrint('🇬🇧/🇩🇪 [TtsService] Selected native voice: ${selectedVoice['name']} (${selectedVoice['locale']})');
      } else {
        await _flutterTts.setLanguage(targetLocale);
        debugPrint('ℹ️ [TtsService] Fallback to system default for $targetLocale');
      }
    } catch (e) {
      debugPrint('⚠️ [TtsService] Voice selection note: $e');
    }
  }

  /// Pre-warms the native speech engine during idle windows with current course language.
  Future<void> warmUp() async {
    try {
      if (!_isInitialized) {
        await init();
      }
      final locale = activeLocale;
      await _flutterTts.setLanguage(locale);
    } catch (e) {
      debugPrint('⚠️ [TtsService] Warmup note: $e');
    }
  }

  /// Pre-warm routine invoked during question result feedback.
  Future<void> prewarmForStage(String stageType, List<String> words) async {
    try {
      if (!_isInitialized) {
        await init();
      }
      final locale = activeLocale;
      await _flutterTts.setLanguage(locale);
      debugPrint('🔥 [TtsService] Pre-warmed for "$stageType" in $locale (${words.length} items)');
    } catch (e) {
      debugPrint('⚠️ [TtsService] prewarmForStage note: $e');
    }
  }

  /// Legacy helper kept for backward compatibility.
  Future<void> precacheWords(List<String> words) async {
    await prewarmForStage('batch', words);
  }

  /// Speak a single target word with instant non-blocking dispatch.
  Future<void> speakWord(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    try {
      if (!_isInitialized) {
        await init();
      }
      final speakable = cleaned.replaceAll(RegExp(r'[,.!?]+$'), '');
      _flutterTts.speak(speakable);
    } catch (e) {
      debugPrint('⚠️ [TtsService] speakWord failed: $e');
    }
  }

  /// Alias for backward compatibility.
  Future<void> speakGerman(String text) => speakWord(text);

  /// Speak a full sentence and optionally await its completion
  Future<void> speakSentence(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    try {
      if (!_isInitialized) {
        await init();
      }
      await _flutterTts.speak(cleaned);
    } catch (e) {
      debugPrint('⚠️ [TtsService] speakSentence failed: $e');
    }
  }

  /// Stop any ongoing speech playback
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('⚠️ [TtsService] stop failed: $e');
    }
  }
}
