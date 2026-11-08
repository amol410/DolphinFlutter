import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/prefetch_service.dart';
import 'models/gamification_models.dart';

class GamificationRepository {
  final CacheService _cache = CacheService();
  final PrefetchService _prefetch = PrefetchService();

  /// Resolves the course trio used for a path request/cache key.
  ///
  /// Callers that already know the active course must pass it explicitly. When
  /// they do not, we consult the persisted status/user course rather than
  /// inventing German, which previously caused an English course to be
  /// replaced by the German curriculum.
  Future<({String target, String native, String level})> _resolveCourse({
    String? targetLanguage,
    String? nativeLanguage,
    String? level,
  }) async {
    var target = targetLanguage;
    var native = nativeLanguage;
    var lvl = level;

    if (target == null || native == null || lvl == null) {
      final cached = await _cache.getCachedStatus();
      target ??= cached?.targetLanguage;
      native ??= cached?.nativeLanguage;
      lvl ??= cached?.currentLevel;
    }

    target ??= 'de';
    native ??= (target == 'en' ? 'mr' : 'en');
    lvl ??= 'A1';

    return (target: target, native: native, level: lvl);
  }

  Future<GamificationStatusModel> getStatus() async {
    // 1. Check local Tier-2 cache
    final cached = await _cache.getCachedStatus();

    try {
      final dio = await DioClient.getInstance();
      final response = await dio.get(ApiConstants.gamificationStatus);
      if (response.data is Map<String, dynamic> &&
          response.data['success'] == true &&
          response.data['status'] != null) {
        final status = GamificationStatusModel.fromJson(response.data['status']);
        await _cache.saveStatus(status);
        return status;
      }
    } catch (e) {
      debugPrint('⚠️ [GamificationRepository] getStatus network error: $e');
    }

    if (cached != null) return cached;
    throw StateError('Gamification status is unavailable');
  }

  static List<PathNodeModel> _parseRawNodes(dynamic rawData) {
    if (rawData is List) {
      return rawData
          .whereType<Map<String, dynamic>>()
          .map((json) => PathNodeModel.fromJson(json))
          .toList();
    }
    return <PathNodeModel>[];
  }

  Future<List<PathNodeModel>> getPath({
    String? targetLanguage,
    String? nativeLanguage,
    String? level,
    int? section,
    int? unit,
    int? startUnit,
    int? endUnit,
  }) async {
    final course = await _resolveCourse(
      targetLanguage: targetLanguage,
      nativeLanguage: nativeLanguage,
      level: level,
    );
    final tLang = course.target;
    final nLang = course.native;
    final lvl = course.level;

    // 1. Check Tier-2 cache for instant offline-first display
    final cachedNodes = await _cache.getCachedPathNodes(
      targetLanguage: tLang,
      nativeLanguage: nLang,
      level: lvl,
    );

    try {
      final dio = await DioClient.getInstance();
      final queryParams = <String, dynamic>{};
      // Always send the resolved course so the backend cannot substitute a
      // different stored course and return nodes for the wrong language.
      queryParams['targetLanguage'] = tLang;
      queryParams['nativeLanguage'] = nLang;
      queryParams['level'] = lvl;
      if (section != null) queryParams['section'] = section;
      if (unit != null) queryParams['unit'] = unit;
      if (startUnit != null) queryParams['startUnit'] = startUnit;
      if (endUnit != null) queryParams['endUnit'] = endUnit;

      final response = await dio.get(
        ApiConstants.gamificationPath,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.data is Map<String, dynamic> &&
          response.data['success'] == true &&
          response.data['nodes'] != null) {
        final list = response.data['nodes'];
        // Slipstream Pillar 4: Off-thread isolate parsing via compute()
        final nodes = await compute(_parseRawNodes, list);

        // If windowed request, merge with cached nodes; if full request, replace cache
        if (startUnit != null && endUnit != null && cachedNodes != null && cachedNodes.isNotEmpty) {
          final mergedMap = {for (final n in cachedNodes) n.index: n};
          for (final n in nodes) {
            mergedMap[n.index] = n;
          }
          final mergedList = mergedMap.values.toList()..sort((a, b) => a.index.compareTo(b.index));
          await _cache.savePathNodes(
            targetLanguage: tLang,
            nativeLanguage: nLang,
            level: lvl,
            nodes: mergedList,
          );
        } else {
          await _cache.savePathNodes(
            targetLanguage: tLang,
            nativeLanguage: nLang,
            level: lvl,
            nodes: nodes,
          );
        }

        // Evict any stale cached lessons based on server updatedAt timestamps
        for (final n in nodes) {
          if (n.id != null && n.updatedAt != null) {
            final cached = await _cache.getCachedLessonDetails(n.id);
            if (cached != null &&
                _cache.isCacheStale(
                  serverUpdatedAt: n.updatedAt,
                  cachedUpdatedAt: cached['updatedAt']?.toString(),
                )) {
              debugPrint('🔄 [GamificationRepository] Evicting stale cache for lesson ${n.id} (updated: ${n.updatedAt})');
              await _cache.removeLessonDetails(n.id);
            }
          }
        }

        // Predictive background prefetch for upcoming unfinished nodes & voice clips
        _prefetch.prefetchUpcomingLessons(nodes);

        return nodes;
      }
    } catch (e) {
      debugPrint('⚠️ [GamificationRepository] getPath network error: $e');
    }

    // Return cached path if network fails (offline support)
    if (cachedNodes != null && cachedNodes.isNotEmpty) {
      debugPrint('⚡ [GamificationRepository] Serving course path from Tier-2 local cache (${cachedNodes.length} nodes)');
      _prefetch.prefetchUpcomingLessons(cachedNodes);
      return cachedNodes;
    }

    // Fallback to complete 7-island Archipelago
    return [
      const PathNodeModel(
        index: 0,
        title: 'Basics & Greetings',
        subtitle: 'Essential German greetings & etiquette',
        type: 'lesson',
        status: 'completed',
        stars: 3,
        scorePct: 100,
        xpReward: 15,
        offset: 0.0,
      ),
      const PathNodeModel(
        index: 1,
        title: 'Audio Karaoke Rhythm',
        subtitle: 'Word-by-word synced listening',
        type: 'karaoke',
        status: 'available',
        stars: 0,
        xpReward: 20,
        offset: 45.0,
      ),
      const PathNodeModel(
        index: 2,
        title: 'Sprechen Lip-Sync',
        subtitle: 'Voice dictation & pronunciation',
        type: 'speech',
        status: 'locked',
        stars: 0,
        xpReward: 25,
        offset: -40.0,
      ),
      const PathNodeModel(
        index: 3,
        title: 'Sunken Treasure Chest',
        subtitle: 'Bonus 30 Pearls & 20 XP',
        type: 'chest',
        status: 'locked',
        stars: 0,
        xpReward: 20,
        pearlsReward: 30,
        offset: 20.0,
      ),
      const PathNodeModel(
        index: 4,
        title: 'Match the Pairs',
        subtitle: 'Rapid vocabulary tile match',
        type: 'match',
        status: 'locked',
        stars: 0,
        xpReward: 20,
        offset: -45.0,
      ),
      const PathNodeModel(
        index: 5,
        title: 'Sentence Architect',
        subtitle: 'Grammar structure puzzle',
        type: 'builder',
        status: 'locked',
        stars: 0,
        xpReward: 20,
        offset: 35.0,
      ),
      const PathNodeModel(
        index: 6,
        title: 'Coral Reef Exam',
        subtitle: 'Mastery challenge to promote',
        type: 'boss',
        status: 'locked',
        stars: 0,
        xpReward: 35,
        offset: 0.0,
      ),
    ];
  }

  String _newAttemptId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<Map<String, dynamic>> completeNode({
    required int nodeIndex,
    int scorePct = 100,
    String? attemptId,
    String? targetLanguage,
    String? nativeLanguage,
    String? level,
  }) async {
    final completionAttemptId = attemptId ?? _newAttemptId();
    final payload = <String, dynamic>{
      'nodeIndex': nodeIndex,
      'scorePct': scorePct,
      'attemptId': completionAttemptId,
      if (targetLanguage != null) 'targetLanguage': targetLanguage,
      if (nativeLanguage != null) 'nativeLanguage': nativeLanguage,
      if (level != null) 'level': level,
    };

    try {
      final dio = await DioClient.getInstance();
      final response = await dio.post(
        ApiConstants.gamificationCompleteNode,
        data: payload,
      );
      if (response.data is Map<String, dynamic>) {
        await replayOfflineCompletions();
        return response.data as Map<String, dynamic>;
      }
      return {'success': false, 'attemptId': completionAttemptId};
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) return data;
        return {
          'success': false,
          'attemptId': completionAttemptId,
          'message': 'Lesson completion was rejected by the server',
        };
      }
      debugPrint('⚠️ [GamificationRepository] completeNode network error, queueing offline: $e');
      await _cache.queueOfflineCompletion(payload);
      return {'success': false, 'offlineQueued': true, 'attemptId': completionAttemptId};
    } catch (e) {
      debugPrint('⚠️ [GamificationRepository] completeNode error, queueing offline: $e');
      await _cache.queueOfflineCompletion(payload);
      return {'success': false, 'offlineQueued': true, 'attemptId': completionAttemptId};
    }
  }

  Future<void>? _replayInFlight;

  Future<void> replayOfflineCompletions() {
    final inFlight = _replayInFlight;
    if (inFlight != null) return inFlight;
    final replay = _performOfflineReplay();
    _replayInFlight = replay;
    return replay.whenComplete(() => _replayInFlight = null);
  }

  Future<void> _performOfflineReplay() async {
    final queue = await _cache.getPendingOfflineCompletions();
    if (queue.isEmpty) return;
    debugPrint('🔄 [GamificationRepository] Replaying ${queue.length} offline completions...');
    final dio = await DioClient.getInstance();

    for (final item in queue) {
      final attemptId = item['attemptId']?.toString();
      if (attemptId == null || attemptId.isEmpty) continue;
      try {
        final response = await dio.post(ApiConstants.gamificationCompleteNode, data: item);
        if (response.data is Map<String, dynamic> && response.data['success'] == true) {
          await _cache.removeOfflineCompletion(attemptId);
        } else {
          break;
        }
      } catch (_) {
        break;
      }
    }
  }

  Future<List<LeaderboardEntryModel>> getLeaderboard({String? league}) async {
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.get(
        ApiConstants.gamificationLeaderboard,
        queryParameters: league != null ? {'league': league} : null,
      );
      if (response.data is Map<String, dynamic> &&
          response.data['success'] == true &&
          response.data['leaderboard'] != null) {
        final list = response.data['leaderboard'] as List;
        return list.map((json) => LeaderboardEntryModel.fromJson(json)).toList();
      }
    } catch (_) {}

    return [
      const LeaderboardEntryModel(rank: 1, name: 'Lukas M.', xp: 340, streak: 12, league: 'Coral Reef'),
      const LeaderboardEntryModel(rank: 2, name: 'You (Dolphin)', xp: 120, streak: 3, isCurrent: true, league: 'Coral Reef'),
      const LeaderboardEntryModel(rank: 3, name: 'Elena R.', xp: 110, streak: 5, league: 'Coral Reef'),
      const LeaderboardEntryModel(rank: 4, name: 'Marco P.', xp: 95, streak: 2, league: 'Coral Reef'),
      const LeaderboardEntryModel(rank: 5, name: 'Sophie K.', xp: 80, streak: 4, league: 'Coral Reef'),
    ];
  }

  Future<bool> refillOxygen() async {
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.post(ApiConstants.gamificationRefillOxygen);
      return response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deductOxygen() async {
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.post(ApiConstants.gamificationDeductOxygen);
      return response.data is Map<String, dynamic> && response.data['success'] == true;
    } catch (e) {
      debugPrint('⚠️ [GamificationRepository] deductOxygen error: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> buyStreakFreeze() async {
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.post(ApiConstants.gamificationBuyStreakFreeze);
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('⚠️ [GamificationRepository] buyStreakFreeze error: $e');
    }
    return {'success': false, 'message': 'Failed to purchase streak freeze'};
  }

  Future<Map<String, dynamic>> buyDoubleXp() async {
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.post(ApiConstants.gamificationBuyDoubleXp);
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('⚠️ [GamificationRepository] buyDoubleXp error: $e');
    }
    return {'success': false, 'message': 'Failed to activate double XP'};
  }

  Future<List<QuestModel>> getQuests() async {
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.get(ApiConstants.gamificationQuests);
      if (response.data is Map<String, dynamic> &&
          response.data['success'] == true &&
          response.data['quests'] is List) {
        final list = response.data['quests'] as List;
        return list.whereType<Map<String, dynamic>>().map((j) => QuestModel.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint('⚠️ [GamificationRepository] getQuests error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> claimQuest(int questId) async {
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.post(
        ApiConstants.gamificationClaimQuest,
        data: {'questId': questId},
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('⚠️ [GamificationRepository] claimQuest error: $e');
    }
    return {'success': false, 'message': 'Failed to claim quest'};
  }

  Future<Map<String, dynamic>?> claimAdReward({
    required String rewardType,
    String? attemptId,
  }) async {
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.post(
        ApiConstants.gamificationClaimAdReward,
        data: {
          'rewardType': rewardType,
          if (attemptId != null) 'attemptId': attemptId,
        },
      );
      if (response.data is Map<String, dynamic> &&
          response.data['success'] == true) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('⚠️ [GamificationRepository] claimAdReward error: $e');
    }
    return null;
  }

  Future<bool> switchCourse({
    required String targetLanguage,
    required String nativeLanguage,
    String level = 'A1',
  }) async {
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.post(
        ApiConstants.gamificationSwitchCourse,
        data: {
          'targetLanguage': targetLanguage,
          'nativeLanguage': nativeLanguage,
          'level': level,
        },
      );
      return response.data is Map<String, dynamic> &&
          response.data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> getLessonDetails(dynamic lessonId, {String? serverUpdatedAt}) async {
    if (lessonId == null) return null;

    // 1. Check local Tier-2 cache first (0ms latency!)
    final cached = await _cache.getCachedLessonDetails(lessonId);
    final isStale = _cache.isCacheStale(
      serverUpdatedAt: serverUpdatedAt,
      cachedUpdatedAt: cached?['updatedAt']?.toString(),
    );

    if (cached != null && !isStale) {
      debugPrint('⚡ [GamificationRepository] Serving lesson $lessonId from Tier-2 cache (0ms instant play)');
      return cached;
    }

    try {
      final dio = await DioClient.getInstance();
      final response = await dio.get('${ApiConstants.gamificationLesson}/$lessonId');
      if (response.data is Map<String, dynamic> &&
          response.data['success'] == true &&
          response.data['lesson'] != null) {
        final lesson = response.data['lesson'] as Map<String, dynamic>;
        await _cache.saveLessonDetails(lessonId, lesson);
        return lesson;
      }
    } catch (e) {
      debugPrint('⚠️ [GamificationRepository] getLessonDetails network error: $e');
    }

    // Offline fallback: if network fails, return cached copy even if potentially stale
    if (cached != null) {
      debugPrint('⚡ [GamificationRepository] Offline fallback: Serving lesson $lessonId from local cache');
      return cached;
    }

    return null;
  }
}

