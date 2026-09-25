import '../../../../core/network/dio_client.dart';
import 'models/activity_model.dart';

class ActivityRepository {
  Future<TodayCounts> getTodayCounts() async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.get('/activity/summary', queryParameters: {
        'countsOnly': 'true',
      });
      final data = response.data;
      if (data != null && data['summary'] != null) {
        return TodayCounts.fromJson(Map<String, dynamic>.from(data['summary']));
      }
      return const TodayCounts();
    } catch (e) {
      return const TodayCounts();
    }
  }

  Future<List<ActivityDayGroup>> getActivityWeek({String? weekOf}) async {
    final dio = await DioClient.getInstance();
    try {
      final weekOfDate = weekOf ?? _getCurrentMondayDate();
      final response = await dio.get('/activity/summary', queryParameters: {
        'weekOf': weekOfDate,
      });
      final data = response.data;
      if (data == null || data['days'] == null) return [];

      final daysMap = data['days'] as Map<String, dynamic>;
      final List<ActivityDayGroup> groups = [];

      for (final entry in daysMap.entries) {
        final dateStr = entry.key;
        final dayData = entry.value as Map<String, dynamic>? ?? {};

        final quizzes = (dayData['quizzes'] as List? ?? [])
            .map((item) => ActivityItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        final notes = (dayData['notes'] as List? ?? [])
            .map((item) => ActivityItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        final flashcards = (dayData['flashcards'] as List? ?? [])
            .map((item) => ActivityItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();
        final karaoke = (dayData['karaoke'] as List? ?? [])
            .map((item) => ActivityItem.fromJson(Map<String, dynamic>.from(item)))
            .toList();

        groups.add(ActivityDayGroup(
          dateStr: dateStr,
          info: DayCategoryInfo.fromDateStr(dateStr),
          quizzes: quizzes,
          notes: notes,
          flashcards: flashcards,
          karaoke: karaoke,
        ));
      }

      // Sort descending by date (Today first, then Yesterday, etc.)
      groups.sort((a, b) => b.dateStr.compareTo(a.dateStr));
      return groups;
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  String _getCurrentMondayDate() {
    final now = DateTime.now();
    final dayOfWeek = (now.weekday - 1) % 7; // 0 = Mon
    final monday = now.subtract(Duration(days: dayOfWeek));
    final y = monday.year.toString().padLeft(4, '0');
    final m = monday.month.toString().padLeft(2, '0');
    final d = monday.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
