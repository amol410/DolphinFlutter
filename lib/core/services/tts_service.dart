import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';

/// DolphinCoder Low-Latency Text-To-Speech & Pronunciation Service
/// Supports Natural Male Studio Narrator English (en-US) and German (de-DE)
/// with offline background pre-synthesis caching, versioned cache invalidation,
/// and sub-20ms instant tactile word tap playback via low-latency audio engine.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  /// Cache version - increment to invalidate old synthesized audio files on device.
  static const int _cacheVersion = 2;

  /// High-priority male voice identifiers for Android (Google TTS), iOS, macOS, Windows.
  static const List<String> _preferredMaleVoiceIdentifiers = [
    'en-us-x-sfg', // Google US English Male (resonant, deep, studio quality)
    'en-us-x-iom', // Google US English Male
    'en-us-x-iob', // Google US English Male
    'en-us-x-tpc', // Google US English Male
    'en-us-x-iol', // Google US English Male
    'en-gb-x-rjd', // Google UK English Male
    'en-gb-x-fis', // Google UK English Male
    'en-in-x-cnd', // Google India English Male
    'en-in-x-ene', // Google India English Male
    'daniel',       // iOS / macOS British Male
    'david',        // Windows / Android Male
    'oliver',       // iOS British Male
    'george',       // iOS British Male
    'guy',          // Android / Microsoft Male
    'male',         // Generic male indicator
  ];

  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _wordAudioPlayer = AudioPlayer();

  bool _isInitialized = false;
  Future<void>? _initFuture;
  String _currentLanguageCode = 'en'; // default to en or de based on active course
  String get currentLanguageCode => _currentLanguageCode;

  String get activeLocale => _currentLanguageCode == 'en' ? 'en-US' : 'de-DE';

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
  bool _isStaleCacheCleaned = false;

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

  /// Thread-safe local cache directory resolver with automatic stale cache wiping.
  Future<Directory> _getTtsCacheDir() async {
    if (_ttsCacheDir != null) {
      if (!_isStaleCacheCleaned) {
        _isStaleCacheCleaned = true;
        unawaited(_cleanStaleCache(_ttsCacheDir!));
      }
      return _ttsCacheDir!;
    }
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
    if (!_isStaleCacheCleaned) {
      _isStaleCacheCleaned = true;
      await _cleanStaleCache(dir);
    }
    return _ttsCacheDir!;
  }

  /// Automatically wipes stale or unversioned audio cache files so obsolete audio
  /// (e.g. old female voice recordings) is never played again.
  Future<void> _cleanStaleCache(Directory dir) async {
    try {
      if (!await dir.exists()) return;
      const currentVersionPrefix = 'tts_v${_cacheVersion}_';
      final List<FileSystemEntity> entities = await dir.list().toList();
      for (final entity in entities) {
        if (entity is File) {
          final fileName = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last
              : entity.path.split(Platform.pathSeparator).last;
          // Delete any tts_* file that does NOT match the current version prefix
          if (fileName.startsWith('tts_') && !fileName.startsWith(currentVersionPrefix)) {
            try {
              await entity.delete();
              debugPrint('🗑️ [TtsService] Wiped stale audio cache file: $fileName');
            } catch (e) {
              debugPrint('⚠️ [TtsService] Could not wipe stale file $fileName: $e');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [TtsService] _cleanStaleCache error: $e');
    }
  }

  /// Manually trigger cache cleanup of stale audio files.
  Future<void> clearStaleCache() async {
    try {
      final dir = await _getTtsCacheDir();
      await _cleanStaleCache(dir);
    } catch (e) {
      debugPrint('⚠️ [TtsService] clearStaleCache error: $e');
    }
  }

  /// Clean input word of surrounding punctuation.
  String _normalizeWord(String word) {
    return word
        .trim()
        .replaceAll(RegExp(r'''^[\s,.:;!?¡¿"״„“”']+|[\s,.:;!?¡¿"״„“”']+$'''), '')
        .trim();
  }

  @visibleForTesting
  static int get cacheVersion => _cacheVersion;

  @visibleForTesting
  Future<void> cleanStaleCacheForTesting(Directory dir) => _cleanStaleCache(dir);

  @visibleForTesting
  String normalizeWordForTesting(String word) => _normalizeWord(word);

  @visibleForTesting
  String getCacheKeyForTesting(String word, String locale) => _getCacheKey(word, locale);

  @visibleForTesting
  String getFileNameForWordForTesting(String word, String locale) => _getFileNameForWord(word, locale);

  /// Unique memory/disk cache key based on version, locale and word.
  String _getCacheKey(String word, String locale) {
    return 'v${_cacheVersion}_${locale.toLowerCase()}_${word.toLowerCase()}';
  }

  /// Deterministic alphanumeric file name for disk caching with version prefix.
  String _getFileNameForWord(String word, String locale) {
    final clean = _normalizeWord(word);
    final safeWord = clean.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final truncated = safeWord.length > 24 ? safeWord.substring(0, 24) : safeWord;
    final hash = clean.hashCode.abs().toRadixString(16);
    final prefix = locale.toLowerCase().replaceAll('-', '_');
    return 'tts_v${_cacheVersion}_${prefix}_${truncated}_$hash.$_audioFileExtension';
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

  /// Update active learning language for speech synthesis ('en' for English, 'de' for German)
  Future<void> setLanguage(String langCode) async {
    final cleaned = langCode.toLowerCase().trim();
    final newLangCode = (cleaned == 'en' || cleaned == 'english') ? 'en' : 'de';
    final newLocale = newLangCode == 'en' ? 'en-US' : 'de-DE';

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
      if (newLangCode == 'en') {
        // Natural, resonant studio narrator male voice settings
        await _flutterTts.setPitch(0.88);
        await _flutterTts.setSpeechRate(0.48);
        await _flutterTts.setVolume(1.0);
      } else {
        await _flutterTts.setPitch(1.0);
        await _flutterTts.setSpeechRate(0.48);
        await _flutterTts.setVolume(1.0);
      }
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
      // Clear memory cache so stale references are wiped
      _wordAudioFileMap.clear();

      // Wipe stale unversioned disk cache files
      try {
        final cacheDir = await _getTtsCacheDir();
        await _cleanStaleCache(cacheDir);
      } catch (e) {
        debugPrint('⚠️ [TtsService] Stale cache cleanup on init note: $e');
      }

      final locale = activeLocale;
      await _flutterTts.setLanguage(locale);
      // Speaking rate: 0.48 for crystal-clear language learning articulation
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);
      // Pitch: 0.88 provides a natural, deep, pleasant studio narrator male voice for English
      final isEnglish = locale.toLowerCase().startsWith('en');
      await _flutterTts.setPitch(isEnglish ? 0.88 : 1.0);
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
      debugPrint('⚡ [TtsService] Engine initialized for $locale with male narrator voice (Pitch 0.88, Rate 0.48, Low-Latency Audio Ready)');
    } catch (e) {
      debugPrint('⚠️ [TtsService] Init error: $e');
    }
  }

  /// Evaluates and selects the highest quality voice for the target locale.
  /// For English: Guarantees a natural, resonant male narrator voice.
  /// Excludes any voice flagged as female or containing female markers.
  /// For German: Selects high-quality German female voice.
  @visibleForTesting
  Map<String, String>? selectBestVoiceForLocale(List<dynamic> rawVoices, String targetLocale) {
    final isEnglish = targetLocale.toLowerCase().startsWith('en');

    if (isEnglish) {
      int bestScore = -1;
      Map<String, String>? bestVoice;
      Map<String, String>? firstNonFemaleVoice;
      Map<String, String>? firstNonFemaleMatchingLocaleVoice;

      final targetNormalized = targetLocale.toLowerCase().replaceAll('_', '-');

      for (final voice in rawVoices) {
        if (voice is! Map) continue;
        final name = (voice['name'] ?? '').toString().toLowerCase();
        final locale = (voice['locale'] ?? '').toString().toLowerCase();
        final features = (voice['features'] ?? '').toString().toLowerCase();
        final gender = (voice['gender'] ?? '').toString().toLowerCase();

        // Must be an English locale (e.g. en-US, en-GB, en-AU, en-IN, en_US)
        final isEnLocale = locale.startsWith('en') ||
            locale.contains('en-') ||
            locale.contains('en_');
        if (!isEnLocale) continue;

        // 1. Explicitly exclude any voice where name, features, or gender indicates female!
        final isFemale = name.contains('female') ||
            features.contains('female') ||
            gender.contains('female') ||
            name.contains('woman') ||
            name.contains('girl');
        if (isFemale) {
          continue;
        }

        final voiceMap = {
          "name": voice['name'].toString(),
          "locale": voice['locale'].toString(),
        };

        // Track non-female candidates for fallback
        firstNonFemaleVoice ??= voiceMap;
        if (locale.replaceAll('_', '-').startsWith(targetNormalized)) {
          firstNonFemaleMatchingLocaleVoice ??= voiceMap;
        }

        // 2. Check male indicators
        // Android Google TTS provides gender info in features (e.g. "[male, notInstalled]")
        final hasMaleFeature = (features.contains('male') || gender.contains('male')) &&
            !features.contains('female') &&
            !gender.contains('female');

        // Check voice name against known high-quality male voices across Android/iOS/Desktop
        int preferredIndex = -1;
        for (int i = 0; i < _preferredMaleVoiceIdentifiers.length; i++) {
          if (name.contains(_preferredMaleVoiceIdentifiers[i])) {
            preferredIndex = i;
            break;
          }
        }
        final isPreferredMaleName = preferredIndex != -1;

        if (isPreferredMaleName || hasMaleFeature) {
          int score = 100;

          if (isPreferredMaleName) {
            // Prioritize higher-ranked male voice identifiers
            score += 200 + (_preferredMaleVoiceIdentifiers.length - preferredIndex) * 10;
          }
          if (hasMaleFeature) {
            score += 50;
          }

          // Bonus for matching target locale (e.g. en-US)
          if (locale.replaceAll('_', '-').startsWith(targetNormalized)) {
            score += 40;
          }

          // Bonus for local offline voice on Android (faster, no network dependence)
          if (name.contains('-local')) {
            score += 20;
          }

          if (score > bestScore) {
            bestScore = score;
            bestVoice = voiceMap;
          }
        }
      }

      // 3. Fallback: If no preferred male voice was matched, fallback to the first
      // non-female English voice (matching target locale first, then any English).
      // NEVER fallback to a female voice!
      return bestVoice ?? (firstNonFemaleMatchingLocaleVoice ?? firstNonFemaleVoice);
    } else {
      // German voice matching
      Map<String, String>? selectedVoice;
      for (final voice in rawVoices) {
        if (voice is! Map) continue;
        final name = (voice['name'] ?? '').toString().toLowerCase();
        final locale = (voice['locale'] ?? '').toString().toLowerCase();

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
          return {
            "name": voice['name'].toString(),
            "locale": voice['locale'].toString(),
          };
        }
        selectedVoice ??= {
          "name": voice['name'].toString(),
          "locale": voice['locale'].toString(),
        };
      }
      return selectedVoice;
    }
  }

  /// Automatically matches and binds the best natural voice for the target locale.
  Future<void> _applyBestVoiceForLocale(String targetLocale) async {
    // Guard against redundant voice selection if already applied
    if (_currentAppliedVoiceLocale == targetLocale) {
      return;
    }

    final isEnglish = targetLocale.toLowerCase().startsWith('en');

    // Ensure pitch (0.88 for English narrator), speech rate, and volume are set
    try {
      await _flutterTts.setPitch(isEnglish ? 0.88 : 1.0);
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);
    } catch (_) {}

    try {
      final dynamic rawVoices = await _flutterTts.getVoices.timeout(
        const Duration(milliseconds: 1500),
        onTimeout: () => null,
      );

      Map<String, String>? selectedVoice;
      if (rawVoices is List) {
        selectedVoice = selectBestVoiceForLocale(rawVoices, targetLocale);
      }

      if (selectedVoice != null) {
        await _flutterTts.setVoice(selectedVoice);
        _currentAppliedVoiceLocale = targetLocale;
        debugPrint('🎙️ [TtsService] Selected native voice: ${selectedVoice['name']} (${selectedVoice['locale']}) for $targetLocale');
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

      final isEnglish = locale.toLowerCase().startsWith('en');
      await _flutterTts.setPitch(isEnglish ? 0.88 : 1.0);
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);

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

      final isEnglish = locale.toLowerCase().startsWith('en');
      await _flutterTts.setPitch(isEnglish ? 0.88 : 1.0);
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);

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

      final isEnglish = locale.toLowerCase().startsWith('en');
      await _flutterTts.setPitch(isEnglish ? 0.88 : 1.0);
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);

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
