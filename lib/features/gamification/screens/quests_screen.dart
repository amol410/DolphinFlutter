import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/widgets/animated_dolphin_mascot.dart';
import '../data/models/gamification_models.dart';
import '../providers/gamification_provider.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  String _getQuestIcon(String type) {
    switch (type) {
      case 'xp':
        return '🔥';
      case 'karaoke':
        return '🎧';
      case 'speech':
        return '🗣️';
      case 'lesson':
        return '📚';
      default:
        return '🎯';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questsAsync = ref.watch(questsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Daily Quests',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await ref.read(questsProvider.notifier).loadQuests();
            await ref.read(gamificationStatusProvider.notifier).refresh();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            children: [
              // Quests Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBAE6FD)),
                ),
                child: Row(
                  children: [
                    const AnimatedDolphinMascot(size: 70, pose: MascotPose.backpack),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DAILY CHALLENGES',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Resets every night at midnight. Complete all to unlock bonus Pearls!',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: const Color(0xFF0369A1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              questsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                  ),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Text('⚠️', style: TextStyle(fontSize: 32)),
                        const SizedBox(height: 8),
                        Text(
                          'Could not load quests right now.',
                          style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                        ),
                        TextButton(
                          onPressed: () => ref.read(questsProvider.notifier).loadQuests(),
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (quests) {
                  if (quests.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          'No active quests for today. Check back later!',
                          style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (final q in quests) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: q.isClaimed
                                  ? const Color(0xFFCBD5E1)
                                  : (q.isCompleted ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: q.isCompleted && !q.isClaimed
                                    ? const Color(0xFFBBF7D0)
                                    : const Color(0xFFE2E8F0),
                                blurRadius: 0,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(_getQuestIcon(q.type), style: const TextStyle(fontSize: 22)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      q.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: q.isClaimed ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                                        decoration: q.isClaimed ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '+${q.rewardPearls} 💎',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(9999),
                                child: LinearProgressIndicator(
                                  value: q.target > 0 ? (q.current / q.target).clamp(0.0, 1.0) : 0,
                                  minHeight: 10,
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor: AlwaysStoppedAnimation(
                                    q.isCompleted ? const Color(0xFF10B981) : const Color(0xFF06B6D4),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  if (q.isCompleted && !q.isClaimed)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () async {
                                        final res = await ref.read(questsProvider.notifier).claimQuest(q.id);
                                        await ref.read(gamificationStatusProvider.notifier).refresh();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(res['message']?.toString() ?? 'Quest claimed! +${q.rewardPearls} 💎'),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      },
                                      child: Text(
                                        'CLAIM REWARD',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, color: Colors.white),
                                      ),
                                    )
                                  else if (q.isClaimed)
                                    Text(
                                      'CLAIMED ✅',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        color: const Color(0xFF10B981),
                                      ),
                                    )
                                  else
                                    const SizedBox.shrink(),
                                  Text(
                                    '${q.current} / ${q.target}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
