import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/cache_service.dart';
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

  void optimisticAddRewards(int xp, int pearls) {
    state.whenData((status) {
      state = AsyncValue.data(status.copyWith(
        totalXp: status.totalXp + xp,
        pearls: status.pearls + pearls,
      ));
    });
  }

  void optimisticRefillOxygen() {
    state.whenData((status) {
      state = AsyncValue.data(status.copyWith(oxygen: 5));
      CacheService().saveStatus(status.copyWith(oxygen: 5));
    });
  }

  void deductOxygen() {
    state.whenData((status) {
      if (status.oxygen > 0) {
        final newOxygen = status.oxygen - 1;
        state = AsyncValue.data(status.copyWith(oxygen: newOxygen));
        CacheService().saveStatus(status.copyWith(oxygen: newOxygen));
      }
    });
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

  Future<bool> claimAdReward(String rewardType, int amount) async {
    state.whenData((status) {
      GamificationStatusModel updated;
      if (rewardType == 'oxygen') {
        final newOxygen = (status.oxygen + amount).clamp(0, 5);
        updated = status.copyWith(oxygen: newOxygen);
      } else if (rewardType == 'pearls') {
        updated = status.copyWith(pearls: status.pearls + amount);
      } else {
        updated = status.copyWith(totalXp: status.totalXp + amount);
      }
      state = AsyncValue.data(updated);
      CacheService().saveStatus(updated);
    });

    try {
      final success = await _repo.claimAdReward(rewardType, amount);
      return success;
    } catch (_) {
      return false;
    }
  }
  Future<bool> switchCourse({
    required String targetLanguage,
    required String nativeLanguage,
    String level = 'A1',
  }) async {
    try {
      final ok = await _repo.switchCourse(
        targetLanguage: targetLanguage,
        nativeLanguage: nativeLanguage,
        level: level,
      );
      if (ok) {
        await refresh();
      }
      return ok;
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
    _initPath();
  }

  Future<void> _initPath() async {
    final status = _ref.read(gamificationStatusProvider).value;
    if (status != null) {
      await loadPath(
        targetLanguage: status.targetLanguage,
        nativeLanguage: status.nativeLanguage,
        level: status.currentLevel,
      );
    } else {
      final cachedStatus = await CacheService().getCachedStatus();
      await loadPath(
        targetLanguage: cachedStatus?.targetLanguage ?? 'de',
        nativeLanguage: cachedStatus?.nativeLanguage ?? 'en',
        level: cachedStatus?.currentLevel ?? 'A1',
      );
    }
  }

  Future<void> loadPath({
    String? targetLanguage,
    String? nativeLanguage,
    String? level,
    int? section,
    bool silent = false,
  }) async {
    if (!silent) {
      state = const AsyncValue.loading();
    }
    try {
      final nodes = await _repo.getPath(
        targetLanguage: targetLanguage,
        nativeLanguage: nativeLanguage,
        level: level,
        section: section,
      );
      state = AsyncValue.data(nodes);
    } catch (e, st) {
      if (!silent) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<bool> completeNode(int nodeIndex, {int stars = 3, int scorePct = 100, int xp = 20, int pearls = 10}) async {
    // 1. Optimistic UI update (0ms instant unlock on client)
    state.whenData((currentNodes) {
      if (nodeIndex >= 0 && nodeIndex < currentNodes.length) {
        final updated = List<PathNodeModel>.from(currentNodes);
        // Mark current node as completed
        updated[nodeIndex] = updated[nodeIndex].copyWith(
          status: 'completed',
          stars: stars,
          scorePct: scorePct,
        );
        // Unlock next node if locked
        if (nodeIndex + 1 < updated.length) {
          if (updated[nodeIndex + 1].status == 'locked') {
            updated[nodeIndex + 1] = updated[nodeIndex + 1].copyWith(status: 'available');
          }
        }
        state = AsyncValue.data(updated);

        // Save updated path to Tier-2 cache immediately
        final statusAsync = _ref.read(gamificationStatusProvider);
        statusAsync.whenData((st) {
          CacheService().savePathNodes(
            targetLanguage: st.targetLanguage,
            nativeLanguage: st.nativeLanguage,
            level: st.currentLevel,
            nodes: updated,
          );
        });
      }
    });

    // 2. Optimistically award pearls and XP in 0ms
    _ref.read(gamificationStatusProvider.notifier).optimisticAddRewards(xp, pearls);

    // 3. Dispatch HTTP sync in the background (no blocking await on 3 round trips!)
    final status = _ref.read(gamificationStatusProvider).asData?.value;
    try {
      _repo.completeNode(
        nodeIndex: nodeIndex,
        stars: stars,
        scorePct: scorePct,
        xpEarned: xp,
        pearlsEarned: pearls,
        targetLanguage: status?.targetLanguage,
        nativeLanguage: status?.nativeLanguage,
        level: status?.currentLevel,
      );
      return true;
    } catch (_) {
      return true;
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
