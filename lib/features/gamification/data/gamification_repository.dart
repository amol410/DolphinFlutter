import 'package:flutter/foundation.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/services/cache_service.dart';
import '../../../../core/services/prefetch_service.dart';
import 'models/gamification_models.dart';

class GamificationRepository {
  final CacheService _cache = CacheService();
  final PrefetchService _prefetch = PrefetchService();

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

    return const GamificationStatusModel(
      streakCount: 1,
      longestStreak: 1,
      dailyTargetXp: 20,
      targetLanguage: 'de',
      pearls: 100,
      oxygen: 5,
      totalXp: 120,
      currentLeague: 'Coral Reef',
    );
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
    final tLang = targetLanguage ?? 'de';
    final nLang = nativeLanguage ?? (tLang == 'en' ? 'mr' : 'en');
    final lvl = level ?? 'A1';

    // 1. Check Tier-2 cache for instant offline-first display
    final cachedNodes = await _cache.getCachedPathNodes(
      targetLanguage: tLang,
      nativeLanguage: nLang,
      level: lvl,
    );

    try {
      final dio = await DioClient.getInstance();
      final queryParams = <String, dynamic>{};
      if (targetLanguage != null) queryParams['targetLanguage'] = targetLanguage;
      if (nativeLanguage != null) queryParams['nativeLanguage'] = nativeLanguage;
      if (level != null) queryParams['level'] = level;
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

  Future<Map<String, dynamic>> completeNode({
    required int nodeIndex,
    int stars = 3,
    int scorePct = 100,
    int xpEarned = 20,
    int pearlsEarned = 10,
    String? targetLanguage,
    String? nativeLanguage,
    String? level,
  }) async {
    final payload = <String, dynamic>{
      'nodeIndex': nodeIndex,
      'stars': stars,
      'scorePct': scorePct,
      'xpEarned': xpEarned,
      'pearlsEarned': pearlsEarned,
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
        _replayOfflineCompletions();
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('⚠️ [GamificationRepository] completeNode network error, queueing offline: $e');
      await _cache.queueOfflineCompletion(payload);
    }
    return {'success': true, 'offlineQueued': true};
  }

  void _replayOfflineCompletions() async {
    try {
      final queue = await _cache.getPendingOfflineCompletions();
      if (queue.isEmpty) return;
      debugPrint('🔄 [GamificationRepository] Replaying ${queue.length} offline completions...');
      final dio = await DioClient.getInstance();
      for (final item in queue) {
        await dio.post(ApiConstants.gamificationCompleteNode, data: item);
      }
      await _cache.clearPendingOfflineCompletions();
      debugPrint('✅ [GamificationRepository] Offline queue synchronized successfully.');
    } catch (_) {}
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
      return true;
    }
  }

  Future<bool> claimAdReward(String rewardType, int amount) async {
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.post(
        ApiConstants.gamificationClaimAdReward,
        data: {'rewardType': rewardType, 'amount': amount},
      );
      return response.data is Map<String, dynamic> &&
          response.data['success'] == true;
    } catch (e) {
      debugPrint('⚠️ [GamificationRepository] claimAdReward network error: $e');
      return true;
    }
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

  Future<Map<String, dynamic>?> getLessonDetails(dynamic lessonId) async {
    if (lessonId == null) return null;

    // 1. Check local Tier-2 cache first (0ms latency!)
    final cached = await _cache.getCachedLessonDetails(lessonId);
    if (cached != null) {
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
    return null;
  }
}

