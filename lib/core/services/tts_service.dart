import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reusable Text-To-Speech Service
/// Optimized for German (de-DE) pronunciation in a natural female / lady voice.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;

  /// Initialize TTS settings, language, and select a German female voice if available
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage("de-DE");
      // Speaking rate: 0.48 for crystal-clear language learning pronunciation
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);
      // Pitch: 1.10 provides a clear, bright female timbre on standard synthesizers
      await _flutterTts.setPitch(1.10);
      // Non-blocking asynchronous mode for instant tactile word taps
      await _flutterTts.awaitSpeakCompletion(false);

      // Attempt to find and set a native female German voice
      final dynamic rawVoices = await _flutterTts.getVoices;
      if (rawVoices is List) {
        bool foundFemale = false;
        for (final voice in rawVoices) {
          if (voice is Map) {
            final name = (voice['name'] ?? '').toString().toLowerCase();
            final locale = (voice['locale'] ?? '').toString().toLowerCase();

            final isGerman = locale.contains('de-de') || locale.contains('de_de');
            if (!isGerman) continue;

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
              await _flutterTts.setVoice({
                "name": voice['name'].toString(),
                "locale": voice['locale'].toString(),
              });
              debugPrint('🔊 [TtsService] Configured German female voice: ${voice['name']}');
              foundFemale = true;
              break;
            }
          }
        }
        if (!foundFemale) {
          debugPrint('ℹ️ [TtsService] Using system default German voice with female pitch 1.10');
        }
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('⚠️ [TtsService] Init error: $e');
    }
  }

  final Set<String> _cachedWords = {};

  /// Pre-warms the native speech engine and AudioTrack so the very first word
  /// tap responds with zero cold-start latency.
  Future<void> warmUp() async {
    try {
      if (!_isInitialized) {
        await init();
      }
      // Prime native German acoustic engine and AudioTrack with a real German phoneme
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.setVolume(0.0);
      await _flutterTts.speak("Ja");
      await _flutterTts.setVolume(1.0);
      await _flutterTts.awaitSpeakCompletion(false);
      debugPrint('⚡ [TtsService] Engine pre-warmed & audio pipeline hot');
    } catch (e) {
      debugPrint('⚠️ [TtsService] Warmup note: $e');
      try {
        await _flutterTts.setVolume(1.0);
        await _flutterTts.awaitSpeakCompletion(false);
      } catch (_) {}
    }
  }

  /// Asynchronously pre-synthesizes vocabulary words in the background.
  /// Uses synthesizeToFile to compile phonemes into cache without interrupting live audio playback.
  Future<void> precacheWords(List<String> words) async {
    if (!_isInitialized) {
      await init();
    }
    final toPrime = <String>[];
    for (final raw in words) {
      final clean = raw.replaceAll(RegExp(r'[,.!?]+$'), '').trim();
      if (clean.isNotEmpty && !_cachedWords.contains(clean.toLowerCase())) {
        _cachedWords.add(clean.toLowerCase());
        toPrime.add(clean);
      }
    }
    if (toPrime.isEmpty) return;

    for (final word in toPrime) {
      try {
        final safeName = word.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
        await _flutterTts.synthesizeToFile(word, 'tts_cache_$safeName.wav');
      } catch (_) {
        break;
      }
    }
    debugPrint('⚡ [TtsService] Pre-synthesized ${toPrime.length} words to cache');
  }

  /// Speak a single German word with instant non-blocking dispatch.
  Future<void> speakGerman(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    try {
      if (!_isInitialized) {
        await init();
      }
      // Ensure volume is restored in case background caching was finishing
      await _flutterTts.setVolume(1.0);
      await _flutterTts.awaitSpeakCompletion(false);
      await _flutterTts.stop();

      // Clean punctuation from isolated word taps (e.g. "dir?", "Morgen," -> "dir", "Morgen")
      final speakable = cleaned.replaceAll(RegExp(r'[,.!?]+$'), '');
      await _flutterTts.speak(speakable);
    } catch (e) {
      debugPrint('⚠️ [TtsService] speakGerman failed: $e');
    }
  }

  /// Speak a full sentence and optionally await its completion
  Future<void> speakSentence(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    try {
      if (!_isInitialized) {
        await init();
      }
      await _flutterTts.setVolume(1.0);
      await _flutterTts.stop();
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.speak(cleaned);
      await _flutterTts.awaitSpeakCompletion(false);
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
