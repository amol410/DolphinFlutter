import 'dart:convert';

class TodayCounts {
  final int quizCount;
  final int noteCount;
  final int flashcardCount;
  final int karaokeCount;
  final int total;

  const TodayCounts({
    this.quizCount = 0,
    this.noteCount = 0,
    this.flashcardCount = 0,
    this.karaokeCount = 0,
    this.total = 0,
  });

  factory TodayCounts.fromJson(Map<String, dynamic> json) {
    return TodayCounts(
      quizCount: json['quizCount'] ?? 0,
      noteCount: json['noteCount'] ?? 0,
      flashcardCount: json['flashcardCount'] ?? 0,
      karaokeCount: json['karaokeCount'] ?? 0,
      total: json['total'] ?? 0,
    );
  }
}

class ActivityItem {
  final int id;
  final String activityType; // 'quiz', 'note', 'flashcard'
  final int resourceId;
  final String resourceTitle;
  final String? subjectName;
  final String? topicName;
  final Map<String, dynamic> metadata;
  final String activityDate;
  final String createdAt;

  const ActivityItem({
    required this.id,
    required this.activityType,
    required this.resourceId,
    required this.resourceTitle,
    this.subjectName,
    this.topicName,
    this.metadata = const {},
    required this.activityDate,
    required this.createdAt,
  });

  factory ActivityItem.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> meta = {};
    if (json['metadata'] != null) {
      if (json['metadata'] is Map) {
        meta = Map<String, dynamic>.from(json['metadata']);
      } else if (json['metadata'] is String) {
        try {
          meta = jsonDecode(json['metadata']);
        } catch (_) {}
      }
    }

    return ActivityItem(
      id: json['id'] is num ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      activityType: json['activityType'] ?? 'note',
      resourceId: json['resourceId'] is num ? (json['resourceId'] as num).toInt() : int.tryParse(json['resourceId']?.toString() ?? '0') ?? 0,
      resourceTitle: json['resourceTitle'] ?? '',
      subjectName: json['subjectName'],
      topicName: json['topicName'],
      metadata: meta,
      activityDate: json['activityDate'] ?? '',
      createdAt: json['createdAt'] ?? '',
    );
  }

  bool get isKaraoke => activityType == 'note' && (metadata['isKaraoke'] == true || metadata['isKaraoke'] == 1);

  int get secondsSpent {
    if (metadata.containsKey('timeTakenSecs')) {
      return (metadata['timeTakenSecs'] is num) ? (metadata['timeTakenSecs'] as num).toInt() : 0;
    }
    if (metadata.containsKey('engagementSecs')) {
      return (metadata['engagementSecs'] is num) ? (metadata['engagementSecs'] as num).toInt() : 0;
    }
    return 0;
  }

  int? get score => (metadata['score'] is num) ? (metadata['score'] as num).toInt() : null;
  int? get maxScore => (metadata['maxScore'] is num) ? (metadata['maxScore'] as num).toInt() : null;
  double? get percentage => (metadata['percentage'] is num) ? (metadata['percentage'] as num).toDouble() : null;
  bool? get passed => metadata['passed'] as bool?;
}

class DayCategoryInfo {
  final String badge;
  final String dateLabel;
  final int diffDays;

  const DayCategoryInfo({
    required this.badge,
    required this.dateLabel,
    required this.diffDays,
  });

  static DayCategoryInfo fromDateStr(String dateStr) {
    try {
      final parts = dateStr.split('-').map(int.parse).toList();
      final target = DateTime(parts[0], parts[1], parts[2]);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = today.difference(target).inDays;

      const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      const shortWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

      final weekday = weekdays[target.weekday - 1];
      final shortWeekday = shortWeekdays[target.weekday - 1];
      final month = months[target.month - 1];
      final dateLabel = '$weekday, $month ${target.day}, ${target.year}';

      if (diff == 0) {
        return DayCategoryInfo(badge: 'TODAY', dateLabel: dateLabel, diffDays: 0);
      } else if (diff == 1) {
        return DayCategoryInfo(badge: 'YESTERDAY', dateLabel: dateLabel, diffDays: 1);
      } else if (diff == 2) {
        return DayCategoryInfo(badge: 'DAY BEFORE YESTERDAY ($shortWeekday)', dateLabel: dateLabel, diffDays: 2);
      } else {
        return DayCategoryInfo(badge: weekday.toUpperCase(), dateLabel: dateLabel, diffDays: diff);
      }
    } catch (_) {
      return DayCategoryInfo(badge: dateStr, dateLabel: dateStr, diffDays: 99);
    }
  }
}

class ActivityDayGroup {
  final String dateStr;
  final DayCategoryInfo info;
  final List<ActivityItem> quizzes;
  final List<ActivityItem> notes;
  final List<ActivityItem> flashcards;
  final List<ActivityItem> karaoke;

  const ActivityDayGroup({
    required this.dateStr,
    required this.info,
    this.quizzes = const [],
    this.notes = const [],
    this.flashcards = const [],
    this.karaoke = const [],
  });

  int get totalSeconds {
    int total = 0;
    for (final q in quizzes) total += q.secondsSpent;
    for (final n in notes) total += n.secondsSpent;
    for (final f in flashcards) total += f.secondsSpent;
    for (final k in karaoke) total += k.secondsSpent;
    return total;
  }

  int get totalActivities => quizzes.length + notes.length + flashcards.length + karaoke.length;
}
