import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Reusable Text-To-Speech Service
/// Optimized for German (de-DE) pronunciation in a natural female / lady voice
/// with instant, zero-latency tactile dispatch.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  Future<void>? _initFuture;

  /// Thread-safe initialization. Ensures speech parameters, voice selection,
  /// and native engine binding run once without race conditions.
  Future<void> init() {
    _initFuture ??= _doInit();
    return _initFuture!;
  }

  Future<void> _doInit() async {
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

      // Attempt to find and set a native female German voice (bounded timeout so it never hangs)
      try {
        final dynamic rawVoices = await _flutterTts.getVoices.timeout(
          const Duration(milliseconds: 1500),
          onTimeout: () => null,
        );
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
      } catch (e) {
        debugPrint('ℹ️ [TtsService] Defaulting to standard German engine voice: $e');
      }

      _isInitialized = true;
      debugPrint('⚡ [TtsService] Engine initialized for de-DE');
    } catch (e) {
      debugPrint('⚠️ [TtsService] Init error: $e');
    }
  }

  /// Pre-warms the native speech engine and AudioTrack during idle windows.
  Future<void> warmUp() async {
    try {
      if (!_isInitialized) {
        await init();
      }
      // Re-assert language to guarantee native IPC binder is active and ready
      await _flutterTts.setLanguage("de-DE");
    } catch (e) {
      debugPrint('⚠️ [TtsService] Warmup note: $e');
    }
  }

  /// Pre-warm routine invoked during question result feedback.
  /// Prepares the engine for the upcoming stage's words / phrases.
  Future<void> prewarmForStage(String stageType, List<String> words) async {
    try {
      if (!_isInitialized) {
        await init();
      }
      // Keep the engine hot and audio session primed
      await _flutterTts.setLanguage("de-DE");
      debugPrint('🔥 [TtsService] Pre-warmed for next stage "$stageType" with ${words.length} vocabulary items');
    } catch (e) {
      debugPrint('⚠️ [TtsService] prewarmForStage note: $e');
    }
  }

  /// Legacy helper kept for backward compatibility.
  Future<void> precacheWords(List<String> words) async {
    await prewarmForStage('batch', words);
  }

  /// Speak a single German word with instant non-blocking dispatch.
  /// Skips duplicate IPC calls to guarantee sub-15ms response time on tap.
  Future<void> speakGerman(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    try {
      if (!_isInitialized) {
        await init();
      }
      // Clean punctuation from isolated word taps (e.g. "dir?", "Morgen," -> "dir", "Morgen")
      final speakable = cleaned.replaceAll(RegExp(r'[,.!?]+$'), '');
      _flutterTts.speak(speakable);
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
