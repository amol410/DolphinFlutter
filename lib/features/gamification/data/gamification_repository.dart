import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import 'models/gamification_models.dart';

class GamificationRepository {
  Future<GamificationStatusModel> getStatus() async {
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.get(ApiConstants.gamificationStatus);
      if (response.data is Map<String, dynamic> &&
          response.data['success'] == true &&
          response.data['status'] != null) {
        return GamificationStatusModel.fromJson(response.data['status']);
      }
    } catch (_) {}
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

  Future<List<PathNodeModel>> getPath({
    String? targetLanguage,
    String? nativeLanguage,
    String? level,
    int? section,
  }) async {
    try {
      final dio = await DioClient.getInstance();
      final queryParams = <String, dynamic>{};
      if (targetLanguage != null) queryParams['targetLanguage'] = targetLanguage;
      if (nativeLanguage != null) queryParams['nativeLanguage'] = nativeLanguage;
      if (level != null) queryParams['level'] = level;
      if (section != null) queryParams['section'] = section;

      final response = await dio.get(
        ApiConstants.gamificationPath,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      if (response.data is Map<String, dynamic> &&
          response.data['success'] == true &&
          response.data['nodes'] != null) {
        final list = response.data['nodes'] as List;
        return list.map((json) => PathNodeModel.fromJson(json)).toList();
      }
    } catch (_) {}

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
  }) async {
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.post(
        ApiConstants.gamificationCompleteNode,
        data: {
          'nodeIndex': nodeIndex,
          'stars': stars,
          'scorePct': scorePct,
          'xpEarned': xpEarned,
          'pearlsEarned': pearlsEarned,
        },
      );
      if (response.data is Map<String, dynamic>) {
        return response.data as Map<String, dynamic>;
      }
    } catch (_) {}
    return {'success': true};
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
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.get('${ApiConstants.gamificationLesson}/$lessonId');
      if (response.data is Map<String, dynamic> &&
          response.data['success'] == true &&
          response.data['lesson'] != null) {
        return response.data['lesson'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }
}

