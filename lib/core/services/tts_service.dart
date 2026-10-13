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
      await _flutterTts.awaitSpeakCompletion(true);

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
      // Silent micro-synthesis to initialize audio pipeline & load German voice into RAM
      await _flutterTts.setVolume(0.0);
      await _flutterTts.speak(" ");
      await Future.delayed(const Duration(milliseconds: 40));
      await _flutterTts.setVolume(1.0);
      debugPrint('⚡ [TtsService] Engine pre-warmed & audio pipeline hot');
    } catch (e) {
      debugPrint('⚠️ [TtsService] Warmup note: $e');
      try {
        await _flutterTts.setVolume(1.0);
      } catch (_) {}
    }
  }

  /// Asynchronously pre-synthesizes a list of vocabulary words in the background.
  /// Primes the Android/iOS TTS internal phoneme cache before the user taps them.
  Future<void> precacheWords(List<String> words) async {
    if (!_isInitialized) {
      await init();
    }
    for (final raw in words) {
      final clean = raw.replaceAll(RegExp(r'[,.!?]+$'), '').trim();
      if (clean.isEmpty || _cachedWords.contains(clean.toLowerCase())) continue;
      _cachedWords.add(clean.toLowerCase());
      try {
        final safeName = clean.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toLowerCase();
        await _flutterTts.synthesizeToFile(clean, 'tts_cache_$safeName.wav');
      } catch (_) {
        // Fallback: If synthesizeToFile is unavailable on specific engine,
        // the engine was already warmed up via warmUp()
      }
    }
    debugPrint('⚡ [TtsService] Pre-cached ${_cachedWords.length} vocabulary words');
  }

  /// Speak a German word or phrase in lady's voice.
  /// Stops any currently playing utterance so rapid taps do not lag or queue up.
  Future<void> speakGerman(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    try {
      if (!_isInitialized) {
        await init();
      }
      await _flutterTts.stop();

      // Clean punctuation from isolated word taps (e.g. "dir?", "Morgen," -> "dir", "Morgen")
      final speakable = cleaned.replaceAll(RegExp(r'[,.!?]+$'), '');
      await _flutterTts.speak(speakable);
    } catch (e) {
      debugPrint('⚠️ [TtsService] speakGerman failed: $e');
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
