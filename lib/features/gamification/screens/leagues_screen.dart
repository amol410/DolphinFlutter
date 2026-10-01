import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../shared/widgets/animated_dolphin_mascot.dart';
import '../providers/gamification_provider.dart';

class LeaguesScreen extends ConsumerWidget {
  const LeaguesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(gamificationStatusProvider);
    final currentLeague = statusAsync.value?.currentLeague ?? 'Coral Reef';
    final leaderboardAsync = ref.watch(leaderboardProvider(currentLeague));

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Oceanic Leagues',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF1E293B),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // League Header Banner with Mascot
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFF0284C7),
                    blurRadius: 0,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const AnimatedDolphinMascot(
                    size: 64,
                    pose: MascotPose.graduation,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentLeague.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Top 10 advance to the next tier • 2d 14h left',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFFE0F2FE),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Leaderboard List
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(leaderboardProvider(currentLeague));
                },
                child: leaderboardAsync.when(
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const Center(child: Text('No learners yet in this league!'));
                    }
                    return ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        final isTop3 = entry.rank <= 3;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: entry.isCurrent ? const Color(0xFFE0F2FE) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: entry.isCurrent
                                  ? const Color(0xFF0284C7)
                                  : isTop3
                                      ? const Color(0xFFF59E0B).withOpacity(0.4)
                                      : const Color(0xFFE2E8F0),
                              width: entry.isCurrent ? 2 : 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text(
                                  entry.rank == 1
                                      ? '🥇'
                                      : entry.rank == 2
                                          ? '🥈'
                                          : entry.rank == 3
                                              ? '🥉'
                                              : '${entry.rank}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFBAE6FD),
                                child: Text(
                                  entry.name.isNotEmpty ? entry.name[0].toUpperCase() : 'L',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  entry.isCurrent ? '${entry.name} (You)' : entry.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: entry.isCurrent ? FontWeight.w900 : FontWeight.w700,
                                    color: entry.isCurrent ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              Text(
                                '${entry.xp} XP',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0284C7)),
                  ),
                  error: (e, _) => Center(child: Text('Error loading leaderboard: $e')),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
