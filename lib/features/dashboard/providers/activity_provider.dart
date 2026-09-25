import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/activity_repository.dart';
import '../data/models/activity_model.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository();
});

final todayCountsProvider = FutureProvider<TodayCounts>((ref) async {
  return ref.watch(activityRepositoryProvider).getTodayCounts();
});

class ActivityHistoryState {
  final List<ActivityDayGroup> days;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String currentMonday;
  final bool hasMore;

  const ActivityHistoryState({
    this.days = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentMonday = '',
    this.hasMore = true,
  });

  ActivityHistoryState copyWith({
    List<ActivityDayGroup>? days,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? currentMonday,
    bool? hasMore,
  }) {
    return ActivityHistoryState(
      days: days ?? this.days,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      currentMonday: currentMonday ?? this.currentMonday,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class ActivityHistoryNotifier extends StateNotifier<ActivityHistoryState> {
  final ActivityRepository _repo;

  ActivityHistoryNotifier(this._repo) : super(const ActivityHistoryState()) {
    fetchInitial();
  }

  String _calcMonday(DateTime dt) {
    final dayOfWeek = (dt.weekday - 1) % 7;
    final mon = dt.subtract(Duration(days: dayOfWeek));
    final y = mon.year.toString().padLeft(4, '0');
    final m = mon.month.toString().padLeft(2, '0');
    final d = mon.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> fetchInitial() async {
    final monStr = _calcMonday(DateTime.now());
    state = state.copyWith(isLoading: true, currentMonday: monStr, hasMore: true);
    try {
      final days = await _repo.getActivityWeek(weekOf: monStr);
      state = state.copyWith(
        days: days,
        isLoading: false,
        currentMonday: monStr,
        hasMore: true,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadPreviousWeek() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);

    try {
      final curMonParts = state.currentMonday.split('-').map(int.parse).toList();
      final curMon = DateTime(curMonParts[0], curMonParts[1], curMonParts[2]);
      final prevMon = curMon.subtract(const Duration(days: 7));
      final prevMonStr = _calcMonday(prevMon);

      final newDays = await _repo.getActivityWeek(weekOf: prevMonStr);
      if (newDays.isEmpty) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      // Merge days avoiding duplicates
      final existingDates = state.days.map((d) => d.dateStr).toSet();
      final filteredNew = newDays.where((d) => !existingDates.contains(d.dateStr)).toList();

      final combined = [...state.days, ...filteredNew];
      combined.sort((a, b) => b.dateStr.compareTo(a.dateStr));

      state = state.copyWith(
        days: combined,
        currentMonday: prevMonStr,
        isLoadingMore: false,
        hasMore: true,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }
}

final activityHistoryProvider =
    StateNotifierProvider<ActivityHistoryNotifier, ActivityHistoryState>((ref) {
  return ActivityHistoryNotifier(ref.watch(activityRepositoryProvider));
});
