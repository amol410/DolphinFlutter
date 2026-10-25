import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

/// DolphinCoder Low-Latency Text-To-Speech & Pronunciation Service
/// Supports British English (en-GB) and German (de-DE) pronunciation
/// with natural voices, offline background pre-synthesis caching,
/// and sub-20ms instant tactile word tap playback via low-latency audio engine.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _wordAudioPlayer = AudioPlayer();

  bool _isInitialized = false;
  Future<void>? _initFuture;
  String _currentLanguageCode = 'en'; // default to en or de based on active course
  String get currentLanguageCode => _currentLanguageCode;

  String get activeLocale => _currentLanguageCode == 'en' ? 'en-GB' : 'de-DE';

  // Guard against redundant native re-configuration
  String? _currentAppliedLocale;
  String? _currentAppliedVoiceLocale;

  // RAM cache: key -> absolute file path for instant zero-latency playback
  final Map<String, String> _wordAudioFileMap = {};

  // Track words currently being synthesized to avoid duplicate concurrent tasks
  final Set<String> _synthesizingWords = {};

  // Background synthesis queue
  final List<String> _precacheQueue = [];
  bool _isProcessingQueue = false;

  Directory? _ttsCacheDir;

  bool get _supportsSynthesizeToFile {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  String get _audioFileExtension {
    if (!kIsWeb && Platform.isIOS) {
      return 'caf';
    }
    return 'wav';
  }

  /// Thread-safe local cache directory resolver.
  Future<Directory> _getTtsCacheDir() async {
    if (_ttsCacheDir != null) return _ttsCacheDir!;
    Directory baseDir;
    try {
      baseDir = await getApplicationSupportDirectory();
    } catch (_) {
      baseDir = await getTemporaryDirectory();
    }
    final dir = Directory('${baseDir.path}/tts_cache');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _ttsCacheDir = dir;
    return _ttsCacheDir!;
  }

  /// Clean input word of surrounding punctuation.
  String _normalizeWord(String word) {
    return word
        .trim()
        .replaceAll(RegExp(r'''^[\s,.:;!?¡¿"״„“”']+|[\s,.:;!?¡¿"״„“”']+$'''), '')
        .trim();
  }

  /// Unique memory/disk cache key based on locale and word.
  String _getCacheKey(String word, String locale) {
    return '${locale.toLowerCase()}_${word.toLowerCase()}';
  }

  /// Deterministic alphanumeric file name for disk caching.
  String _getFileNameForWord(String word, String locale) {
    final clean = _normalizeWord(word);
    final safeWord = clean.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final truncated = safeWord.length > 24 ? safeWord.substring(0, 24) : safeWord;
    final hash = clean.hashCode.abs().toRadixString(16);
    final prefix = locale.toLowerCase().replaceAll('-', '_');
    return 'tts_${prefix}_${truncated}_$hash.$_audioFileExtension';
  }

  /// Check if a pre-synthesized file exists on disk.
  Future<File?> _getCachedWordFile(String word, String locale) async {
    try {
      final dir = await _getTtsCacheDir();
      final fileName = _getFileNameForWord(word, locale);
      final file = File('${dir.path}/$fileName');
      if (await file.exists() && (await file.length()) > 0) {
        return file;
      }
    } catch (e) {
      debugPrint('⚠️ [TtsService] _getCachedWordFile error: $e');
    }
    return null;
  }

  /// Update active learning language for speech synthesis ('en' for British English, 'de' for German)
  Future<void> setLanguage(String langCode) async {
    final cleaned = langCode.toLowerCase().trim();
    final newLangCode = (cleaned == 'en' || cleaned == 'english') ? 'en' : 'de';
    final newLocale = newLangCode == 'en' ? 'en-GB' : 'de-DE';

    final bool languageChanged = _currentLanguageCode != newLangCode;
    _currentLanguageCode = newLangCode;

    if (!_isInitialized) {
      await init();
      return;
    }

    // Guard against redundant native re-configuration
    if (!languageChanged && _currentAppliedLocale == newLocale) {
      return;
    }

    try {
      await _flutterTts.setLanguage(newLocale);
      await _applyBestVoiceForLocale(newLocale);
      _currentAppliedLocale = newLocale;
      debugPrint('🔊 [TtsService] Switched speech synthesis language to $newLocale');
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

      if (_supportsSynthesizeToFile) {
        try {
          await _flutterTts.awaitSynthCompletion(true);
        } catch (_) {}
      }

      await _applyBestVoiceForLocale(locale);
      _currentAppliedLocale = locale;

      // Configure low-latency player for sub-20ms word pronunciation
      try {
        await _wordAudioPlayer.setPlayerMode(PlayerMode.lowLatency);
        await _wordAudioPlayer.setVolume(1.0);
      } catch (e) {
        debugPrint('⚠️ [TtsService] Word AudioPlayer mode setup: $e');
      }

      _isInitialized = true;
      debugPrint('⚡ [TtsService] Engine initialized for $locale (Low-Latency Audio Ready)');
    } catch (e) {
      debugPrint('⚠️ [TtsService] Init error: $e');
    }
  }

  /// Automatically matches and binds the best natural voice for the target locale.
  /// For 'en-GB': selects British English female / natural accent (rjs, gda, fis, etc.)
  /// For 'de-DE': selects German female voice (anna, katja, eva, etc.)
  Future<void> _applyBestVoiceForLocale(String targetLocale) async {
    // Guard against redundant voice selection if already applied
    if (_currentAppliedVoiceLocale == targetLocale) {
      return;
    }

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
        _currentAppliedVoiceLocale = targetLocale;
        debugPrint('🇬🇧/🇩🇪 [TtsService] Selected native voice: ${selectedVoice['name']} (${selectedVoice['locale']})');
      } else {
        await _flutterTts.setLanguage(targetLocale);
        _currentAppliedVoiceLocale = targetLocale;
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
        return;
      }
      final locale = activeLocale;
      if (_currentAppliedLocale != locale) {
        await _flutterTts.setLanguage(locale);
        await _applyBestVoiceForLocale(locale);
        _currentAppliedLocale = locale;
      }
    } catch (e) {
      debugPrint('⚠️ [TtsService] Warmup note: $e');
    }
  }

  /// Pre-warm routine invoked during question result feedback or stage transitions.
  /// Enqueues background pre-synthesis to local cache for instant (< 20ms) word taps.
  Future<void> prewarmForStage(String stageType, List<String> words) async {
    try {
      if (!_isInitialized) {
        await init();
      }
      final locale = activeLocale;
      if (_currentAppliedLocale != locale) {
        await _flutterTts.setLanguage(locale);
        await _applyBestVoiceForLocale(locale);
        _currentAppliedLocale = locale;
      }
      debugPrint('🔥 [TtsService] Pre-warming for "$stageType" in $locale (${words.length} items)');
      if (words.isNotEmpty && _supportsSynthesizeToFile) {
        unawaited(_backgroundPrecache(words, locale));
      }
    } catch (e) {
      debugPrint('⚠️ [TtsService] prewarmForStage note: $e');
    }
  }

  /// Precaches word batch for instant playback.
  Future<void> precacheWords(List<String> words) async {
    await prewarmForStage('batch', words);
  }

  /// Enqueue words for background pre-synthesis.
  Future<void> _backgroundPrecache(List<String> words, String locale) async {
    for (final raw in words) {
      final clean = _normalizeWord(raw);
      if (clean.isEmpty || clean.length > 80) continue;

      final key = _getCacheKey(clean, locale);
      if (_wordAudioFileMap.containsKey(key) ||
          _synthesizingWords.contains(key) ||
          _precacheQueue.contains(clean)) {
        continue;
      }
      _precacheQueue.add(clean);
    }

    if (!_isProcessingQueue) {
      unawaited(_processPrecacheQueue(locale));
    }
  }

  /// Sequential background synthesis runner.
  Future<void> _processPrecacheQueue(String locale) async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      while (_precacheQueue.isNotEmpty) {
        final word = _precacheQueue.removeAt(0);
        final key = _getCacheKey(word, locale);

        if (_wordAudioFileMap.containsKey(key)) continue;

        // Check if file already exists in local disk cache
        final cached = await _getCachedWordFile(word, locale);
        if (cached != null) {
          _wordAudioFileMap[key] = cached.path;
          continue;
        }

        _synthesizingWords.add(key);
        try {
          await _synthesizeWordToFile(word, locale);
        } finally {
          _synthesizingWords.remove(key);
        }

        // Small yield between synthesis calls to keep UI and audio thread smooth
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
    } catch (e) {
      debugPrint('⚠️ [TtsService] _processPrecacheQueue error: $e');
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Synthesize a single word to file and add to cache map.
  Future<String?> _synthesizeWordToFile(String word, String locale) async {
    if (!_supportsSynthesizeToFile) return null;

    final key = _getCacheKey(word, locale);
    try {
      final dir = await _getTtsCacheDir();
      final fileName = _getFileNameForWord(word, locale);
      final filePath = '${dir.path}/$fileName';
      final targetFile = File(filePath);

      if (await targetFile.exists() && (await targetFile.length()) > 0) {
        _wordAudioFileMap[key] = filePath;
        return filePath;
      }

      // Ensure native engine is configured for this locale
      if (_currentAppliedLocale != locale) {
        await _flutterTts.setLanguage(locale);
        await _applyBestVoiceForLocale(locale);
        _currentAppliedLocale = locale;
      }

      // Synthesize to disk
      await _flutterTts
          .synthesizeToFile(word, filePath, true)
          .timeout(
            const Duration(seconds: 4),
            onTimeout: () => null,
          );

      // Verify file presence
      for (int i = 0; i < 5; i++) {
        if (await targetFile.exists() && (await targetFile.length()) > 0) {
          _wordAudioFileMap[key] = filePath;
          debugPrint('🎧 [TtsService] Pre-synthesized word "$word" ($locale) -> $filePath');
          return filePath;
        }
        await Future<void>.delayed(const Duration(milliseconds: 40));
      }
    } catch (e) {
      debugPrint('⚠️ [TtsService] synthesizeToFile failed for "$word": $e');
    }
    return null;
  }

  /// Synthesize a single priority word in background.
  Future<void> _precacheSingleWord(String word, String locale) async {
    final key = _getCacheKey(word, locale);
    if (_wordAudioFileMap.containsKey(key) || _synthesizingWords.contains(key)) {
      return;
    }
    _precacheQueue.insert(0, word);
    if (!_isProcessingQueue) {
      unawaited(_processPrecacheQueue(locale));
    }
  }

  /// Speak a single target word with instant non-blocking dispatch (< 20ms).
  /// Checks RAM/disk cache for pre-synthesized audio and plays via low-latency player;
  /// falls back to native TTS and queues synthesis for future taps.
  Future<void> speakWord(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;

    final speakable = _normalizeWord(cleaned);
    if (speakable.isEmpty) return;

    try {
      if (!_isInitialized) {
        await init();
      }

      final locale = activeLocale;
      final key = _getCacheKey(speakable, locale);

      // 1. Check in-memory map or disk cache
      String? cachedPath = _wordAudioFileMap[key];

      if (cachedPath == null) {
        final cachedFile = await _getCachedWordFile(speakable, locale);
        if (cachedFile != null) {
          cachedPath = cachedFile.path;
          _wordAudioFileMap[key] = cachedPath;
        }
      }

      // 2. Instant playback via low-latency AudioPlayer (< 20ms)
      if (cachedPath != null) {
        try {
          await _wordAudioPlayer.stop();
          await _wordAudioPlayer.play(
            DeviceFileSource(cachedPath),
            mode: PlayerMode.lowLatency,
          );
          debugPrint('⚡ [TtsService] Instant word audio tap (<20ms): "$speakable"');
          return;
        } catch (e) {
          debugPrint('⚠️ [TtsService] Low-latency playback failed, falling back to TTS: $e');
          _wordAudioFileMap.remove(key);
        }
      }

      // 3. Fallback to native flutterTts.speak
      if (_currentAppliedLocale != locale) {
        await _flutterTts.setLanguage(locale);
        await _applyBestVoiceForLocale(locale);
        _currentAppliedLocale = locale;
      }

      _flutterTts.speak(speakable);

      // 4. Background synthesis for future instant taps
      if (_supportsSynthesizeToFile) {
        unawaited(_precacheSingleWord(speakable, locale));
      }
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
      final locale = activeLocale;
      if (_currentAppliedLocale != locale) {
        await _flutterTts.setLanguage(locale);
        await _applyBestVoiceForLocale(locale);
        _currentAppliedLocale = locale;
      }

      // Stop any active word sound before sentence playback
      try {
        await _wordAudioPlayer.stop();
      } catch (_) {}

      await _flutterTts.speak(cleaned);
    } catch (e) {
      debugPrint('⚠️ [TtsService] speakSentence failed: $e');
    }
  }

  /// Stop any ongoing speech or low-latency word playback
  Future<void> stop() async {
    try {
      await _wordAudioPlayer.stop();
    } catch (_) {}
    try {
      await _flutterTts.stop();
    } catch (e) {
      debugPrint('⚠️ [TtsService] stop failed: $e');
    }
  }
}
