import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/gamification_repository.dart';
import '../data/models/gamification_models.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  return GamificationRepository();
});

class GamificationStatusNotifier extends StateNotifier<AsyncValue<GamificationStatusModel>> {
  final GamificationRepository _repo;

  GamificationStatusNotifier(this._repo) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    try {
      final status = await _repo.getStatus();
      state = AsyncValue.data(status);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> refillOxygen() async {
    try {
      final success = await _repo.refillOxygen();
      if (success) {
        await refresh();
      }
      return success;
    } catch (_) {
      return false;
    }
  }
}

final gamificationStatusProvider = StateNotifierProvider<GamificationStatusNotifier, AsyncValue<GamificationStatusModel>>((ref) {
  final repo = ref.watch(gamificationRepositoryProvider);
  return GamificationStatusNotifier(repo);
});

class PathNodesNotifier extends StateNotifier<AsyncValue<List<PathNodeModel>>> {
  final GamificationRepository _repo;
  final Ref _ref;

  PathNodesNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    loadPath();
  }

  Future<void> loadPath() async {
    try {
      final nodes = await _repo.getPath();
      state = AsyncValue.data(nodes);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> completeNode(int nodeIndex, {int stars = 3, int scorePct = 100, int xp = 20, int pearls = 10}) async {
    try {
      final result = await _repo.completeNode(
        nodeIndex: nodeIndex,
        stars: stars,
        scorePct: scorePct,
        xpEarned: xp,
        pearlsEarned: pearls,
      );
      if (result['success'] == true) {
        // Reload path and refresh user stats
        await loadPath();
        _ref.read(gamificationStatusProvider.notifier).refresh();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

final pathNodesProvider = StateNotifierProvider<PathNodesNotifier, AsyncValue<List<PathNodeModel>>>((ref) {
  final repo = ref.watch(gamificationRepositoryProvider);
  return PathNodesNotifier(repo, ref);
});

final leaderboardProvider = FutureProvider.family<List<LeaderboardEntryModel>, String?>((ref, league) async {
  final repo = ref.watch(gamificationRepositoryProvider);
  return repo.getLeaderboard(league: league);
});
