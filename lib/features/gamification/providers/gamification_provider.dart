import 'package:flutter/foundation.dart';
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
      if (!mounted) return;
      state = AsyncValue.data(status);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  void applyServerStatus(Map<String, dynamic> values) {
    state.whenData((status) {
      final updated = status.copyWith(
        totalXp: values['totalXp'] as int?,
        pearls: values['pearls'] as int?,
        oxygen: values['oxygen'] as int?,
        streakCount: values['streakCount'] as int?,
      );
      state = AsyncValue.data(updated);
      CacheService().saveStatus(updated);
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
    // Server-authoritative loss sync to ensure cross-device consistency
    _repo.deductOxygen().catchError((e) {
      debugPrint('⚠️ [GamificationStatusNotifier] Server deductOxygen sync note: $e');
      return false;
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

  Future<bool> claimAdReward({
    required String rewardType,
    String? attemptId,
  }) async {
    try {
      final res = await _repo.claimAdReward(
        rewardType: rewardType,
        attemptId: attemptId,
      );
      if (res != null && res['success'] == true) {
        state.whenData((status) {
          final updated = status.copyWith(
            oxygen: res['oxygen'] as int? ?? status.oxygen,
            pearls: res['pearls'] as int? ?? status.pearls,
            totalXp: res['totalXp'] as int? ?? status.totalXp,
          );
          state = AsyncValue.data(updated);
          CacheService().saveStatus(updated);
        });
        await refresh();
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ [GamificationStatusNotifier] claimAdReward error: $e');
    }

    // Optimistic fallback for testing / offline resilience
    if (rewardType == 'oxygen') {
      state.whenData((status) {
        final newOxygen = (status.oxygen + 3).clamp(0, 5);
        final updated = status.copyWith(oxygen: newOxygen);
        state = AsyncValue.data(updated);
        CacheService().saveStatus(updated);
      });
      return true;
    }
    return false;
  }

  Future<Map<String, dynamic>> buyStreakFreeze() async {
    final result = await _repo.buyStreakFreeze();
    if (result['success'] == true) {
      await refresh();
    }
    return result;
  }

  Future<Map<String, dynamic>> buyDoubleXp() async {
    final result = await _repo.buyDoubleXp();
    if (result['success'] == true) {
      await refresh();
    }
    return result;
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
  int _loadedMaxUnit = 4;
  bool _isFetchingWindow = false;

  PathNodesNotifier(this._repo, this._ref) : super(const AsyncValue.loading()) {
    _initPath();
  }

  Future<void> _initPath() async {
    final status = _ref.read(gamificationStatusProvider).value;
    final cachedStatus = await CacheService().getCachedStatus();
    final tLang = status?.targetLanguage ?? cachedStatus?.targetLanguage ?? 'de';
    final nLang = status?.nativeLanguage ?? cachedStatus?.nativeLanguage ?? 'en';
    final lvl = status?.currentLevel ?? cachedStatus?.currentLevel ?? 'A1';

    // Slipstream Pillar 3: 0 ms Instant Render (Stale-While-Revalidate)
    // 1. Immediately paint cached path from Tier-2 local storage without blocking
    final cachedNodes = await CacheService().getCachedPathNodes(
      targetLanguage: tLang,
      nativeLanguage: nLang,
      level: lvl,
    );
    if (!mounted) return;
    if (cachedNodes != null && cachedNodes.isNotEmpty) {
      state = AsyncValue.data(cachedNodes);
      final maxU = cachedNodes.map((n) => n.unitNumber).fold(1, (prev, u) => u > prev ? u : prev);
      _loadedMaxUnit = maxU < 4 ? 4 : maxU;
    }

    // 2. Background sync with Hostinger API seamlessly (silent = true if cached data is painted)
    if (!mounted) return;
    await loadPath(
      targetLanguage: tLang,
      nativeLanguage: nLang,
      level: lvl,
      startUnit: 1,
      endUnit: _loadedMaxUnit < 4 ? 4 : _loadedMaxUnit,
      silent: cachedNodes != null && cachedNodes.isNotEmpty,
    );
  }

  Future<void> loadPath({
    String? targetLanguage,
    String? nativeLanguage,
    String? level,
    int? section,
    int? unit,
    int? startUnit,
    int? endUnit,
    bool silent = false,
  }) async {
    if (!silent && state.value == null) {
      state = const AsyncValue.loading();
    }
    try {
      final nodes = await _repo.getPath(
        targetLanguage: targetLanguage,
        nativeLanguage: nativeLanguage,
        level: level,
        section: section,
        unit: unit,
        startUnit: startUnit,
        endUnit: endUnit,
      );
      if (!mounted) return;

      if (startUnit != null && endUnit != null && state.value != null && state.value!.isNotEmpty) {
        // Merge windowed nodes into existing list smoothly
        final current = state.value!;
        final mergedMap = {for (final n in current) n.index: n};
        for (final n in nodes) {
          mergedMap[n.index] = n;
        }
        final merged = mergedMap.values.toList()..sort((a, b) => a.index.compareTo(b.index));
        state = AsyncValue.data(merged);
      } else {
        state = AsyncValue.data(nodes);
      }
    } catch (e, st) {
      if (!mounted) return;
      if (!silent && state.value == null) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  // Slipstream Pillar 2: Proactive Lookahead Fetch (Triggered within 600px of scroll boundary)
  Future<void> fetchNextUnitsLookahead() async {
    if (_isFetchingWindow) return;
    _isFetchingWindow = true;

    try {
      final status = _ref.read(gamificationStatusProvider).value;
      final cachedStatus = await CacheService().getCachedStatus();
      final tLang = status?.targetLanguage ?? cachedStatus?.targetLanguage ?? 'de';
      final nLang = status?.nativeLanguage ?? cachedStatus?.nativeLanguage ?? 'en';
      final lvl = status?.currentLevel ?? cachedStatus?.currentLevel ?? 'A1';

      final nextStart = _loadedMaxUnit + 1;
      final nextEnd = _loadedMaxUnit + 3; // Proactively fetch 2-3 units ahead (~12 KB)

      final newNodes = await _repo.getPath(
        targetLanguage: tLang,
        nativeLanguage: nLang,
        level: lvl,
        startUnit: nextStart,
        endUnit: nextEnd,
      );

      if (newNodes.isNotEmpty) {
        _loadedMaxUnit = nextEnd;
        final current = state.value ?? [];
        final mergedMap = {for (final n in current) n.index: n};
        for (final n in newNodes) {
          mergedMap[n.index] = n;
        }
        final merged = mergedMap.values.toList()..sort((a, b) => a.index.compareTo(b.index));
        state = AsyncValue.data(merged);
      }
    } catch (e) {
      // Background lookahead errors fail silently without interrupting active UI
    } finally {
      _isFetchingWindow = false;
    }
  }

  Future<Map<String, dynamic>> completeNode(
    int nodeIndex, {
    int scorePct = 100,
    String? attemptId,
  }) async {
    final status = _ref.read(gamificationStatusProvider).asData?.value;
    final result = await _repo.completeNode(
      nodeIndex: nodeIndex,
      scorePct: scorePct,
      attemptId: attemptId,
      targetLanguage: status?.targetLanguage,
      nativeLanguage: status?.nativeLanguage,
      level: status?.currentLevel,
    );

    if (result['success'] != true) return result;

    final serverStars = result['stars'] as int? ?? 1;
    final serverScore = result['scorePct'] as int? ?? scorePct;
    state.whenData((currentNodes) {
      final updated = List<PathNodeModel>.from(currentNodes);
      final targetPos = updated.indexWhere((n) => n.index == nodeIndex);
      final resolvedPos = targetPos != -1
          ? targetPos
          : (nodeIndex >= 0 && nodeIndex < updated.length ? nodeIndex : -1);
      if (resolvedPos != -1) {
        updated[resolvedPos] = updated[resolvedPos].copyWith(
          status: 'completed',
          stars: serverStars,
          scorePct: serverScore,
        );
        final nextPos = updated.indexWhere((n) => n.index == nodeIndex + 1);
        final resolvedNextPos = nextPos != -1
            ? nextPos
            : (resolvedPos + 1 < updated.length ? resolvedPos + 1 : -1);
        if (resolvedNextPos != -1 && updated[resolvedNextPos].status == 'locked') {
          updated[resolvedNextPos] = updated[resolvedNextPos].copyWith(status: 'available');
        }
        state = AsyncValue.data(updated);

        final currentStatus = _ref.read(gamificationStatusProvider).value;
        if (currentStatus != null) {
          CacheService().savePathNodes(
            targetLanguage: currentStatus.targetLanguage,
            nativeLanguage: currentStatus.nativeLanguage,
            level: currentStatus.currentLevel,
            nodes: updated,
          );
        }
      }
    });

    _ref.read(gamificationStatusProvider.notifier).applyServerStatus(result);
    return result;
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

class QuestsNotifier extends StateNotifier<AsyncValue<List<QuestModel>>> {
  final GamificationRepository _repo;

  QuestsNotifier(this._repo) : super(const AsyncValue.loading()) {
    loadQuests();
  }

  Future<void> loadQuests() async {
    try {
      final list = await _repo.getQuests();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Map<String, dynamic>> claimQuest(int questId) async {
    final result = await _repo.claimQuest(questId);
    if (result['success'] == true) {
      await loadQuests();
    }
    return result;
  }
}

final questsProvider = StateNotifierProvider<QuestsNotifier, AsyncValue<List<QuestModel>>>((ref) {
  final repo = ref.watch(gamificationRepositoryProvider);
  return QuestsNotifier(repo);
});
