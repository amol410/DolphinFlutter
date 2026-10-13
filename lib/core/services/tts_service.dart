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
