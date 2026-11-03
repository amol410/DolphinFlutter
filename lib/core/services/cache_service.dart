import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/gamification/data/models/gamification_models.dart';

/// DolphinCoder Tier-2 Local Persistence Cache Service
/// Inspired by Duolingo's local storage architecture (DiskFileStore & SQLite)
/// Provides sub-10ms synchronous/fast asynchronous reads for course paths,
/// user progression status, lesson stages, offline sync queues, and audio clips.
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  SharedPreferences? _prefs;
  Directory? _audioCacheDir;
  String? _activeUserId;
  bool _legacyCleanupDone = false;

  String? get activeUserId => _activeUserId;

  @visibleForTesting
  void setAudioCacheDir(Directory dir) {
    _audioCacheDir = dir;
  }

  @visibleForTesting
  void reset() {
    _prefs = null;
    _audioCacheDir = null;
    _activeUserId = null;
    _legacyCleanupDone = false;
  }

  Future<void> setActiveUser(String? userId) async {
    if (_activeUserId != userId) {
      _audioCacheDir = null;
    }
    _activeUserId = userId;
    if (userId == null || _legacyCleanupDone) return;

    final prefs = await _getPrefs();
    final legacyKeys = prefs.getKeys().where((key) =>
        key == 'cached_user_status' ||
        key == 'cached_offline_completions' ||
        key.startsWith('cached_path_') ||
        key.startsWith('cached_lesson_'));
    for (final key in legacyKeys) {
      await prefs.remove(key);
    }
    _legacyCleanupDone = true;
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  String get _userPrefix {
    final userId = _activeUserId;
    if (userId == null || userId.isEmpty) {
      throw StateError('An active user is required for gamification cache access');
    }
    return 'dolphin_u_${Uri.encodeComponent(userId)}_';
  }

  String _scopedKey(String suffix) => '$_userPrefix$suffix';

  // ==========================================
  // 1. COURSE PATH CACHING (Stale-While-Revalidate)
  // ==========================================

  String _formatCourseKey(String targetLang, String nativeLang, String level) {
    return _scopedKey('path_${targetLang.toLowerCase()}_${nativeLang.toLowerCase()}_${level.toLowerCase()}');
  }

  static String _encodePathNodesToJson(List<PathNodeModel> nodes) {
    final rawList = nodes.map((n) => n.toJson()).toList();
    return jsonEncode(rawList);
  }

  static List<PathNodeModel> _decodePathNodesFromJson(String jsonStr) {
    try {
      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((item) => PathNodeModel.fromJson(item))
            .toList();
      }
    } catch (_) {}
    return <PathNodeModel>[];
  }

  Future<void> savePathNodes({
    required String targetLanguage,
    required String nativeLanguage,
    required String level,
    required List<PathNodeModel> nodes,
  }) async {
    try {
      final prefs = await _getPrefs();
      final key = _formatCourseKey(targetLanguage, nativeLanguage, level);
      // Slipstream Pillar 4: Off-Thread Isolate Serialization via compute()
      final jsonStr = await compute(_encodePathNodesToJson, nodes);
      await prefs.setString(key, jsonStr);
    } catch (e) {
      debugPrint('⚠️ [CacheService] savePathNodes error: $e');
    }
  }

  Future<List<PathNodeModel>?> getCachedPathNodes({
    required String targetLanguage,
    required String nativeLanguage,
    required String level,
  }) async {
    try {
      final prefs = await _getPrefs();
      final key = _formatCourseKey(targetLanguage, nativeLanguage, level);
      final jsonStr = prefs.getString(key);
      if (jsonStr == null || jsonStr.isEmpty) return null;

      // Slipstream Pillar 4: Off-Thread Isolate Deserialization via compute()
      final nodes = await compute(_decodePathNodesFromJson, jsonStr);
      if (nodes.isNotEmpty) return nodes;
    } catch (e) {
      debugPrint('⚠️ [CacheService] getCachedPathNodes error: $e');
    }
    return null;
  }

  // ==========================================
  // 2. USER PROGRESSION & STATUS CACHING
  // ==========================================

  Future<void> saveStatus(GamificationStatusModel status) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_scopedKey('status'), jsonEncode(status.toJson()));
    } catch (e) {
      debugPrint('⚠️ [CacheService] saveStatus error: $e');
    }
  }

  Future<GamificationStatusModel?> getCachedStatus() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(_scopedKey('status'));
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return GamificationStatusModel.fromJson(decoded);
      }
    } catch (e) {
      debugPrint('⚠️ [CacheService] getCachedStatus error: $e');
    }
    return null;
  }

  // ==========================================
  // 3. LESSON DETAILS & STAGES CACHING
  // ==========================================

  Future<void> saveLessonDetails(dynamic lessonId, Map<String, dynamic> lessonData) async {
    if (lessonId == null) return;
    try {
      final prefs = await _getPrefs();
      await prefs.setString(_scopedKey('lesson_$lessonId'), jsonEncode(lessonData));
    } catch (e) {
      debugPrint('⚠️ [CacheService] saveLessonDetails error: $e');
    }
  }

  Future<Map<String, dynamic>?> getCachedLessonDetails(dynamic lessonId) async {
    if (lessonId == null) return null;
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(_scopedKey('lesson_$lessonId'));
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      debugPrint('⚠️ [CacheService] getCachedLessonDetails error: $e');
    }
    return null;
  }

  Future<void> removeLessonDetails(dynamic lessonId) async {
    if (lessonId == null) return;
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_scopedKey('lesson_$lessonId'));
    } catch (e) {
      debugPrint('⚠️ [CacheService] removeLessonDetails error: $e');
    }
  }

  /// Determines whether a cached lesson is stale compared to the server updatedAt timestamp.
  /// If server has a timestamp and cached either has none (legacy cache) or an older one, it is stale.
  bool isCacheStale({String? serverUpdatedAt, String? cachedUpdatedAt}) {
    if (serverUpdatedAt == null || serverUpdatedAt.isEmpty) return false;
    if (cachedUpdatedAt == null || cachedUpdatedAt.isEmpty) return true;
    try {
      final serverDate = DateTime.parse(serverUpdatedAt);
      final cachedDate = DateTime.parse(cachedUpdatedAt);
      return serverDate.isAfter(cachedDate);
    } catch (_) {
      return serverUpdatedAt != cachedUpdatedAt;
    }
  }

  // ==========================================
  // 4. OFFLINE REQUEST REPLAY QUEUE
  // ==========================================

  Future<void> queueOfflineCompletion(Map<String, dynamic> payload) async {
    try {
      final prefs = await _getPrefs();
      final currentQueue = await getPendingOfflineCompletions();
      currentQueue.add({
        ...payload,
        '_timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      await prefs.setString(_scopedKey('offline_completions'), jsonEncode(currentQueue));
      debugPrint('📦 [CacheService] Queued offline completion. Total in queue: ${currentQueue.length}');
    } catch (e) {
      debugPrint('⚠️ [CacheService] queueOfflineCompletion error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPendingOfflineCompletions() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(_scopedKey('offline_completions'));
      if (jsonStr == null || jsonStr.isEmpty) return [];

      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList();
      }
    } catch (e) {
      debugPrint('⚠️ [CacheService] getPendingOfflineCompletions error: $e');
    }
    return [];
  }

  Future<void> removeOfflineCompletion(String attemptId) async {
    try {
      final prefs = await _getPrefs();
      final currentQueue = await getPendingOfflineCompletions();
      final remaining = currentQueue.where((item) => item['attemptId'] != attemptId).toList();
      if (remaining.isEmpty) {
        await prefs.remove(_scopedKey('offline_completions'));
      } else {
        await prefs.setString(_scopedKey('offline_completions'), jsonEncode(remaining));
      }
    } catch (e) {
      debugPrint('⚠️ [CacheService] removeOfflineCompletion error: $e');
    }
  }

  Future<void> clearPendingOfflineCompletions() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_scopedKey('offline_completions'));
    } catch (e) {
      debugPrint('⚠️ [CacheService] clearPendingOfflineCompletions error: $e');
    }
  }

  Future<void> clearActiveUserCache() async {
    if (_activeUserId == null) return;
    try {
      final prefs = await _getPrefs();
      final prefix = _userPrefix;
      for (final key in prefs.getKeys().where((key) => key.startsWith(prefix))) {
        await prefs.remove(key);
      }
      if (_audioCacheDir != null && await _audioCacheDir!.exists()) {
        await _audioCacheDir!.delete(recursive: true);
        _audioCacheDir = null;
      }
    } catch (e) {
      debugPrint('⚠️ [CacheService] clearActiveUserCache error: $e');
    }
  }

  // ==========================================
  // 5. LOCAL AUDIO DISK CACHE (Bounded LRU Eviction)
  // ==========================================

  static const int maxAudioCacheBytes = 50 * 1024 * 1024; // 50 MB bounded cache limit
  static const int maxAudioFileCount = 50; // max 50 cached audio clips

  Future<Directory> _getAudioCacheDir() async {
    if (_audioCacheDir != null) return _audioCacheDir!;
    final baseDir = await getApplicationSupportDirectory();
    final audioDir = Directory('${baseDir.path}/cache_audio_tts/$_userPrefix');
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    _audioCacheDir = audioDir;
    return _audioCacheDir!;
  }

  String _sanitizeUrlToFilename(String url) {
    // Generate clean deterministic alphanumeric file name with original extension
    final uri = Uri.tryParse(url);
    final ext = uri != null && uri.path.contains('.')
        ? '.${uri.path.split('.').last}'
        : '.mp3';
    final safeHash = url.hashCode.abs().toRadixString(16);
    return 'audio_$safeHash$ext';
  }

  Future<File?> getCachedAudioFile(String url) async {
    if (url.isEmpty || !url.startsWith('http')) return null;
    try {
      final dir = await _getAudioCacheDir();
      final filename = _sanitizeUrlToFilename(url);
      final file = File('${dir.path}/$filename');
      if (await file.exists() && await file.length() > 0) {
        // Touch file last modified date for LRU recency tracking
        try {
          await file.setLastModified(DateTime.now());
        } catch (_) {}
        return file;
      }
    } catch (e) {
      debugPrint('⚠️ [CacheService] getCachedAudioFile error: $e');
    }
    return null;
  }

  Future<File?> saveAudioBytes(String url, List<int> bytes) async {
    if (url.isEmpty || bytes.isEmpty) return null;
    try {
      final dir = await _getAudioCacheDir();
      final filename = _sanitizeUrlToFilename(url);
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);

      // Enforce storage bounds with LRU eviction
      await pruneAudioCacheLru();
      return file;
    } catch (e) {
      debugPrint('⚠️ [CacheService] saveAudioBytes error: $e');
      return null;
    }
  }

  /// Prunes oldest unaccessed files when total size or file count exceeds configured thresholds
  Future<void> pruneAudioCacheLru({
    int maxBytes = maxAudioCacheBytes,
    int maxFiles = maxAudioFileCount,
  }) async {
    try {
      final dir = await _getAudioCacheDir();
      if (!await dir.exists()) return;

      final entities = dir.listSync().whereType<File>().toList();
      if (entities.isEmpty) return;

      // Map files to their stats and sort by last modified ascending (oldest first)
      final filesWithStat = entities.map((f) {
        return (file: f, stat: f.statSync());
      }).toList();

      filesWithStat.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));

      int totalBytes = filesWithStat.fold(0, (acc, item) => acc + item.stat.size);
      int totalFiles = filesWithStat.length;

      for (final item in filesWithStat) {
        if (totalBytes <= maxBytes && totalFiles <= maxFiles) break;
        try {
          final size = item.stat.size;
          item.file.deleteSync();
          totalBytes -= size;
          totalFiles -= 1;
          debugPrint('🧹 [CacheService] LRU evicted audio cache file: ${item.file.path} ($size bytes)');
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('⚠️ [CacheService] pruneAudioCacheLru error: $e');
    }
  }
}
