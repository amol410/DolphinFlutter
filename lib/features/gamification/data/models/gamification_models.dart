class GamificationStatusModel {
  final int streakCount;
  final int longestStreak;
  final String? lastActiveDate;
  final int dailyTargetXp;
  final String targetLanguage;
  final int pearls;
  final int oxygen;
  final int totalXp;
  final String currentLeague;

  const GamificationStatusModel({
    this.streakCount = 1,
    this.longestStreak = 1,
    this.lastActiveDate,
    this.dailyTargetXp = 20,
    this.targetLanguage = 'de',
    this.pearls = 100,
    this.oxygen = 5,
    this.totalXp = 0,
    this.currentLeague = 'Coral Reef',
  });

  factory GamificationStatusModel.fromJson(Map<String, dynamic> json) {
    return GamificationStatusModel(
      streakCount: json['streakCount'] ?? 1,
      longestStreak: json['longestStreak'] ?? 1,
      lastActiveDate: json['lastActiveDate']?.toString(),
      dailyTargetXp: json['dailyTargetXp'] ?? 20,
      targetLanguage: json['targetLanguage'] ?? 'de',
      pearls: json['pearls'] ?? 100,
      oxygen: json['oxygen'] ?? 5,
      totalXp: json['totalXp'] ?? 0,
      currentLeague: json['currentLeague'] ?? 'Coral Reef',
    );
  }
}

class PathNodeModel {
  final int index;
  final String title;
  final String subtitle;
  final String type; // lesson, karaoke, speech, chest, match, builder, boss
  final String status; // locked, available, completed
  final int stars;
  final int scorePct;
  final int xpReward;
  final int pearlsReward;
  final String? sourceType; // note, quiz
  final dynamic sourceId;
  final double offset;
  final String? audioUrl;
  final List<dynamic>? stages;

  const PathNodeModel({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.type,
    this.status = 'locked',
    this.stars = 0,
    this.scorePct = 0,
    this.xpReward = 20,
    this.pearlsReward = 0,
    this.sourceType,
    this.sourceId,
    this.offset = 0.0,
    this.audioUrl,
    this.stages,
  });

  factory PathNodeModel.fromJson(Map<String, dynamic> json) {
    return PathNodeModel(
      index: json['index'] ?? 0,
      title: json['title'] ?? '',
      subtitle: json['subtitle'] ?? '',
      type: json['type'] ?? 'lesson',
      status: json['status'] ?? 'locked',
      stars: json['stars'] ?? 0,
      scorePct: json['scorePct'] ?? 0,
      xpReward: json['xpReward'] ?? 20,
      pearlsReward: json['pearlsReward'] ?? 0,
      sourceType: json['sourceType']?.toString(),
      sourceId: json['sourceId'],
      offset: (json['offset'] as num?)?.toDouble() ?? 0.0,
      audioUrl: json['audioUrl']?.toString(),
      stages: json['stages'] as List<dynamic>?,
    );
  }
}

class LeaderboardEntryModel {
  final int rank;
  final dynamic id;
  final String name;
  final String? avatar;
  final int xp;
  final int streak;
  final bool isCurrent;
  final String league;

  const LeaderboardEntryModel({
    required this.rank,
    this.id,
    required this.name,
    this.avatar,
    required this.xp,
    this.streak = 1,
    this.isCurrent = false,
    this.league = 'Coral Reef',
  });

  factory LeaderboardEntryModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntryModel(
      rank: json['rank'] ?? 0,
      id: json['id'],
      name: json['name'] ?? 'Learner',
      avatar: json['avatar']?.toString(),
      xp: json['xp'] ?? 0,
      streak: json['streak'] ?? 1,
      isCurrent: json['isCurrent'] ?? false,
      league: json['league'] ?? 'Coral Reef',
    );
  }
}
