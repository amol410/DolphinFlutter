import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/subject_badge.dart';
import '../data/models/activity_model.dart';
import '../providers/activity_provider.dart';

class ActivityHistoryScreen extends ConsumerStatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  ConsumerState<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends ConsumerState<ActivityHistoryScreen> {
  String _activeFilter = 'all'; // 'all', 'quiz', 'note', 'flashcard'

  String _formatDuration(int secs) {
    if (secs <= 0) return '0m';
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    if (h > 0) {
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    }
    if (m > 0 && s > 0) return '${m}m ${s}s';
    if (m > 0) return '${m}m';
    return '${s}s';
  }

  Color _getBadgeColor(DayCategoryInfo info) {
    if (info.diffDays == 0) return const Color(0xFF06B6D4); // Cyan for TODAY
    if (info.diffDays == 1) return const Color(0xFF3B82F6); // Blue for YESTERDAY
    if (info.diffDays == 2) return const Color(0xFF8B5CF6); // Purple for DAY BEFORE YESTERDAY
    return AppColors.primaryLight;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityHistoryProvider);
    final todayCountsAsync = ref.watch(todayCountsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Study & Activity History',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(todayCountsProvider);
          await ref.read(activityHistoryProvider.notifier).fetchInitial();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            // ── Today's Milestone Performance Card ──
            todayCountsAsync.maybeWhen(
              data: (counts) => Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.2),
                      const Color(0xFFA855F7).withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.today_rounded, size: 18, color: AppColors.primaryLight),
                        const SizedBox(width: 8),
                        Text(
                          'Today\'s Milestones',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${counts.total} completed',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _MilestoneMini(icon: '🧠', label: 'Quizzes', count: counts.quizCount, color: AppColors.accent),
                        _MilestoneMini(icon: '📝', label: 'Notes', count: counts.noteCount, color: AppColors.noteBlue),
                        _MilestoneMini(icon: '🎤', label: 'Karaoke', count: counts.karaokeCount, color: const Color(0xFF06B6D4)),
                        _MilestoneMini(icon: '🃏', label: 'Cards', count: counts.flashcardCount, color: AppColors.success),
                      ],
                    ),
                  ],
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),

            // ── Filter Chips ──
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(label: 'All Activity', isSelected: _activeFilter == 'all', onTap: () => setState(() => _activeFilter = 'all')),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Quizzes', isSelected: _activeFilter == 'quiz', onTap: () => setState(() => _activeFilter = 'quiz')),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Notes & Karaoke', isSelected: _activeFilter == 'note', onTap: () => setState(() => _activeFilter = 'note')),
                  const SizedBox(width: 8),
                  _FilterChip(label: 'Flashcards', isSelected: _activeFilter == 'flashcard', onTap: () => setState(() => _activeFilter = 'flashcard')),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Daily History List ──
            if (state.isLoading)
              const ShimmerListLoader(count: 3)
            else if (state.days.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.history_rounded, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'No study history found',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Complete a quiz, read a note, or review flashcards to track your progress!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              ...state.days.map((dayGroup) {
                // Filter items according to activeFilter
                List<ActivityItem> filteredItems = [];
                if (_activeFilter == 'all') {
                  filteredItems = [
                    ...dayGroup.quizzes,
                    ...dayGroup.karaoke,
                    ...dayGroup.notes,
                    ...dayGroup.flashcards,
                  ];
                } else if (_activeFilter == 'quiz') {
                  filteredItems = dayGroup.quizzes;
                } else if (_activeFilter == 'note') {
                  filteredItems = [...dayGroup.karaoke, ...dayGroup.notes];
                } else if (_activeFilter == 'flashcard') {
                  filteredItems = dayGroup.flashcards;
                }

                if (filteredItems.isEmpty) return const SizedBox.shrink();

                final badgeColor = _getBadgeColor(dayGroup.info);
                final totalStudyTimeStr = _formatDuration(dayGroup.totalSeconds);

                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Day Group Header ──
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface2.withOpacity(0.5),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                          border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: badgeColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: badgeColor.withOpacity(0.4)),
                                    ),
                                    child: Text(
                                      dayGroup.info.badge,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: badgeColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    dayGroup.info.dateLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Daily Study Hours (Right Side Header)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 14, color: AppColors.primaryLight),
                                  const SizedBox(width: 5),
                                  Text(
                                    totalStudyTimeStr,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Activity Rows ──
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final item = filteredItems[i];
                          return _ActivityCard(item: item);
                        },
                      ),
                    ],
                  ),
                );
              }),

              // ── Load Previous Week Button ──
              if (state.hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: state.isLoadingMore
                        ? null
                        : () => ref.read(activityHistoryProvider.notifier).loadPreviousWeek(),
                    icon: state.isLoadingMore
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.arrow_downward_rounded, size: 16),
                    label: Text(
                      state.isLoadingMore ? 'Loading History...' : 'Load Previous Week',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MilestoneMini extends StatelessWidget {
  final String icon;
  final String label;
  final int count;
  final Color color;

  const _MilestoneMini({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 3),
        Text(
          '$count',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityItem item;

  const _ActivityCard({required this.item});

  String _formatSeconds(int secs) {
    if (secs <= 0) return '0s';
    final m = secs ~/ 60;
    final s = secs % 60;
    if (m > 0 && s > 0) return '${m}m ${s}s';
    if (m > 0) return '${m}m';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final isQuiz = item.activityType == 'quiz';
    final isKaraoke = item.isKaraoke;
    final isFlashcard = item.activityType == 'flashcard';

    IconData typeIcon = Icons.article_outlined;
    Color typeColor = AppColors.noteBlue;
    String typeLabel = 'Note';

    if (isQuiz) {
      typeIcon = Icons.psychology_outlined;
      typeColor = AppColors.accent;
      typeLabel = 'Quiz';
    } else if (isKaraoke) {
      typeIcon = Icons.music_note_rounded;
      typeColor = const Color(0xFF06B6D4);
      typeLabel = 'Karaoke';
    } else if (isFlashcard) {
      typeIcon = Icons.style_outlined;
      typeColor = AppColors.success;
      typeLabel = 'Flashcard';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (isQuiz) {
            context.push('/quizzes/${item.resourceId}/review');
          } else if (isKaraoke) {
            context.push('/notes/karaoke/${item.resourceId}');
          } else if (isFlashcard) {
            context.push('/flashcards/${item.resourceId}/study');
          } else {
            context.push('/notes/${item.resourceId}');
          }
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface2.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(typeIcon, size: 18, color: typeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          typeLabel,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: typeColor,
                          ),
                        ),
                        if (item.subjectName != null && item.subjectName!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          SubjectBadge(label: item.subjectName!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.resourceTitle.isNotEmpty ? item.resourceTitle : 'Resource #${item.resourceId}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Right outcome badge
              if (isQuiz && item.percentage != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (item.passed == true ? AppColors.success : AppColors.error).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item.percentage!.round()}%',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: item.passed == true ? AppColors.success : AppColors.error,
                        ),
                      ),
                    ),
                    if (item.secondsSpent > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatSeconds(item.secondsSpent),
                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                      ),
                    ],
                  ],
                ),
              ] else if (item.secondsSpent > 0) ...[
                Text(
                  _formatSeconds(item.secondsSpent),
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }
}
