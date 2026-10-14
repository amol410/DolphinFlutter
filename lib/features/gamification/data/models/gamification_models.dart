class GamificationStatusModel {
  final int streakCount;
  final int longestStreak;
  final String? lastActiveDate;
  final int dailyTargetXp;
  final String targetLanguage;
  final String nativeLanguage;
  final String currentLevel;
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
    this.nativeLanguage = 'en',
    this.currentLevel = 'A1',
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
      nativeLanguage: json['nativeLanguage'] ?? (json['targetLanguage'] == 'en' ? 'mr' : 'en'),
      currentLevel: json['currentLevel'] ?? 'A1',
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
  final int unitNumber;
  final String unitTitle;
  final String unitDescription;
  final int sectionNumber;
  final String sectionTitle;
  final int sectionUnitNumber;
  final String colorHex;

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
    this.unitNumber = 1,
    this.unitTitle = 'Erste Schritte',
    this.unitDescription = 'Basic Greetings & Introductions',
    this.sectionNumber = 1,
    this.sectionTitle = 'Rookie',
    this.sectionUnitNumber = 1,
    this.colorHex = '#1CB0F6',
  });

  factory PathNodeModel.fromJson(Map<String, dynamic> json) {
    final uNum = json['unitNumber'] is num ? (json['unitNumber'] as num).toInt() : 1;
    final secNum = json['sectionNumber'] is num
        ? (json['sectionNumber'] as num).toInt()
        : (uNum <= 35 ? 1 : (uNum <= 70 ? 2 : 3));
    final secUnit = json['sectionUnitNumber'] is num
        ? (json['sectionUnitNumber'] as num).toInt()
        : (secNum == 1 ? uNum : (secNum == 2 ? uNum - 35 : uNum - 70));
    final secTitle = json['sectionTitle']?.toString() ??
        (secNum == 1 ? 'Rookie' : (secNum == 2 ? 'Explorer' : 'Traveler'));

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
      unitNumber: uNum,
      unitTitle: json['unitTitle']?.toString() ?? 'Erste Schritte',
      unitDescription: json['unitDescription']?.toString() ?? '',
      sectionNumber: secNum,
      sectionTitle: secTitle,
      sectionUnitNumber: secUnit,
      colorHex: json['colorHex']?.toString() ?? '#1CB0F6',
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
