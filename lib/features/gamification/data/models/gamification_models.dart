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
  final int streakFreezeCount;
  final bool isDoubleXpActive;
  final String? doubleXpExpiresAt;

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
    this.streakFreezeCount = 0,
    this.isDoubleXpActive = false,
    this.doubleXpExpiresAt,
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
      streakFreezeCount: json['streakFreezeCount'] ?? 0,
      isDoubleXpActive: json['isDoubleXpActive'] == true,
      doubleXpExpiresAt: json['doubleXpExpiresAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'streakCount': streakCount,
      'longestStreak': longestStreak,
      'lastActiveDate': lastActiveDate,
      'dailyTargetXp': dailyTargetXp,
      'targetLanguage': targetLanguage,
      'nativeLanguage': nativeLanguage,
      'currentLevel': currentLevel,
      'pearls': pearls,
      'oxygen': oxygen,
      'totalXp': totalXp,
      'currentLeague': currentLeague,
      'streakFreezeCount': streakFreezeCount,
      'isDoubleXpActive': isDoubleXpActive,
      'doubleXpExpiresAt': doubleXpExpiresAt,
    };
  }

  GamificationStatusModel copyWith({
    int? streakCount,
    int? longestStreak,
    String? lastActiveDate,
    int? dailyTargetXp,
    String? targetLanguage,
    String? nativeLanguage,
    String? currentLevel,
    int? pearls,
    int? oxygen,
    int? totalXp,
    String? currentLeague,
    int? streakFreezeCount,
    bool? isDoubleXpActive,
    String? doubleXpExpiresAt,
  }) {
    return GamificationStatusModel(
      streakCount: streakCount ?? this.streakCount,
      longestStreak: longestStreak ?? this.longestStreak,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      dailyTargetXp: dailyTargetXp ?? this.dailyTargetXp,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      nativeLanguage: nativeLanguage ?? this.nativeLanguage,
      currentLevel: currentLevel ?? this.currentLevel,
      pearls: pearls ?? this.pearls,
      oxygen: oxygen ?? this.oxygen,
      totalXp: totalXp ?? this.totalXp,
      currentLeague: currentLeague ?? this.currentLeague,
      streakFreezeCount: streakFreezeCount ?? this.streakFreezeCount,
      isDoubleXpActive: isDoubleXpActive ?? this.isDoubleXpActive,
      doubleXpExpiresAt: doubleXpExpiresAt ?? this.doubleXpExpiresAt,
    );
  }
}

class QuestModel {
  final int id;
  final String title;
  final String type; // xp, karaoke, speech, lesson
  final int current;
  final int target;
  final int rewardPearls;
  final int rewardXp;
  final bool isCompleted;
  final bool isClaimed;

  const QuestModel({
    required this.id,
    required this.title,
    required this.type,
    required this.current,
    required this.target,
    required this.rewardPearls,
    required this.rewardXp,
    required this.isCompleted,
    required this.isClaimed,
  });

  factory QuestModel.fromJson(Map<String, dynamic> json) {
    return QuestModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'xp',
      current: json['current'] as int? ?? 0,
      target: json['target'] as int? ?? 1,
      rewardPearls: json['rewardPearls'] as int? ?? 15,
      rewardXp: json['rewardXp'] as int? ?? 20,
      isCompleted: json['isCompleted'] == true,
      isClaimed: json['isClaimed'] == true,
    );
  }

  double get progressPct => target <= 0 ? 1.0 : (current / target).clamp(0.0, 1.0);

  QuestModel copyWith({
    int? id,
    String? title,
    String? type,
    int? current,
    int? target,
    int? rewardPearls,
    int? rewardXp,
    bool? isCompleted,
    bool? isClaimed,
  }) {
    return QuestModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      current: current ?? this.current,
      target: target ?? this.target,
      rewardPearls: rewardPearls ?? this.rewardPearls,
      rewardXp: rewardXp ?? this.rewardXp,
      isCompleted: isCompleted ?? this.isCompleted,
      isClaimed: isClaimed ?? this.isClaimed,
    );
  }
}

class PathNodeModel {
  final dynamic id;
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
    this.id,
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
      id: json['id'] ?? json['sourceId'],
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'index': index,
      'title': title,
      'subtitle': subtitle,
      'type': type,
      'status': status,
      'stars': stars,
      'scorePct': scorePct,
      'xpReward': xpReward,
      'pearlsReward': pearlsReward,
      'sourceType': sourceType,
      'sourceId': sourceId,
      'offset': offset,
      'audioUrl': audioUrl,
      'stages': stages,
      'unitNumber': unitNumber,
      'unitTitle': unitTitle,
      'unitDescription': unitDescription,
      'sectionNumber': sectionNumber,
      'sectionTitle': sectionTitle,
      'sectionUnitNumber': sectionUnitNumber,
      'colorHex': colorHex,
    };
  }

  PathNodeModel copyWith({
    dynamic id,
    int? index,
    String? title,
    String? subtitle,
    String? type,
    String? status,
    int? stars,
    int? scorePct,
    int? xpReward,
    int? pearlsReward,
    String? sourceType,
    dynamic sourceId,
    double? offset,
    String? audioUrl,
    List<dynamic>? stages,
    int? unitNumber,
    String? unitTitle,
    String? unitDescription,
    int? sectionNumber,
    String? sectionTitle,
    int? sectionUnitNumber,
    String? colorHex,
  }) {
    return PathNodeModel(
      id: id ?? this.id,
      index: index ?? this.index,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      type: type ?? this.type,
      status: status ?? this.status,
      stars: stars ?? this.stars,
      scorePct: scorePct ?? this.scorePct,
      xpReward: xpReward ?? this.xpReward,
      pearlsReward: pearlsReward ?? this.pearlsReward,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      offset: offset ?? this.offset,
      audioUrl: audioUrl ?? this.audioUrl,
      stages: stages ?? this.stages,
      unitNumber: unitNumber ?? this.unitNumber,
      unitTitle: unitTitle ?? this.unitTitle,
      unitDescription: unitDescription ?? this.unitDescription,
      sectionNumber: sectionNumber ?? this.sectionNumber,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      sectionUnitNumber: sectionUnitNumber ?? this.sectionUnitNumber,
      colorHex: colorHex ?? this.colorHex,
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
