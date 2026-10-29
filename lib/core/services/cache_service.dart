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

  static const String _prefixPath = 'cached_path_';
  static const String _keyStatus = 'cached_user_status';
  static const String _prefixLesson = 'cached_lesson_';
  static const String _keyOfflineQueue = 'cached_offline_completions';

  SharedPreferences? _prefs;

  @visibleForTesting
  void setAudioCacheDir(Directory dir) {
    _audioCacheDir = dir;
  }

  @visibleForTesting
  void reset() {
    _prefs = null;
    _audioCacheDir = null;
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ==========================================
  // 1. COURSE PATH CACHING (Stale-While-Revalidate)
  // ==========================================

  String _formatCourseKey(String targetLang, String nativeLang, String level) {
    return '$_prefixPath${targetLang.toLowerCase()}_${nativeLang.toLowerCase()}_${level.toLowerCase()}';
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
      await prefs.setString(_keyStatus, jsonEncode(status.toJson()));
    } catch (e) {
      debugPrint('⚠️ [CacheService] saveStatus error: $e');
    }
  }

  Future<GamificationStatusModel?> getCachedStatus() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(_keyStatus);
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
      await prefs.setString('$_prefixLesson$lessonId', jsonEncode(lessonData));
    } catch (e) {
      debugPrint('⚠️ [CacheService] saveLessonDetails error: $e');
    }
  }

  Future<Map<String, dynamic>?> getCachedLessonDetails(dynamic lessonId) async {
    if (lessonId == null) return null;
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString('$_prefixLesson$lessonId');
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
      await prefs.setString(_keyOfflineQueue, jsonEncode(currentQueue));
      debugPrint('📦 [CacheService] Queued offline completion. Total in queue: ${currentQueue.length}');
    } catch (e) {
      debugPrint('⚠️ [CacheService] queueOfflineCompletion error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPendingOfflineCompletions() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(_keyOfflineQueue);
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

  Future<void> clearPendingOfflineCompletions() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_keyOfflineQueue);
    } catch (e) {
      debugPrint('⚠️ [CacheService] clearPendingOfflineCompletions error: $e');
    }
  }

  // ==========================================
  // 5. LOCAL AUDIO DISK CACHE (CacheDir.AUDIO_TTS)
  // ==========================================

  Directory? _audioCacheDir;

  Future<Directory> _getAudioCacheDir() async {
    if (_audioCacheDir != null) return _audioCacheDir!;
    final baseDir = await getApplicationSupportDirectory();
    final audioDir = Directory('${baseDir.path}/cache_audio_tts');
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
      return file;
    } catch (e) {
      debugPrint('⚠️ [CacheService] saveAudioBytes error: $e');
      return null;
    }
  }
}
