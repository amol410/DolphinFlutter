import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/empty_state.dart';
import '../providers/quiz_provider.dart';
import '../data/models/quiz_model.dart';
import '../../notes/screens/notes_screen.dart' show subjectsProvider;
import '../../auth/providers/auth_provider.dart';

class QuizzesScreen extends ConsumerStatefulWidget {
  const QuizzesScreen({super.key});

  @override
  ConsumerState<QuizzesScreen> createState() => _QuizzesScreenState();
}

class _QuizzesScreenState extends ConsumerState<QuizzesScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _selectedSubjectId = '';
  String _selectedTopic = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(quizzesListProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final state = ref.watch(quizzesListProvider);
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(Icons.school_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'DolphinCoder',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          'Quizzes',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.surfaceContainerHigh,
                            border: Border.all(color: Colors.white, width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              user?.initials ?? 'S',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Bar & Filter Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Search Bar
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (q) {
                        Future.delayed(const Duration(milliseconds: 350), () {
                          if (_searchController.text == q) {
                            ref.read(quizzesListProvider.notifier).search(q);
                          }
                        });
                      },
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search quizzes by title or keyword...',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: AppColors.onSurfaceVariant.withOpacity(0.65),
                        ),
                        prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.onSurfaceVariant),
                        suffixIcon: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(Icons.tune_rounded, size: 18, color: AppColors.onSurfaceVariant),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Subject Filter Row
                  subjectsAsync.when(
                    loading: () => const SizedBox(height: 38),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (subjects) => SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: subjects.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            final isSel = _selectedSubjectId.isEmpty;
                            return _QuizSubjectChip(
                              label: 'All',
                              icon: Icons.apps_rounded,
                              isSelected: isSel,
                              onTap: () {
                                setState(() {
                                  _selectedSubjectId = '';
                                  _selectedTopic = '';
                                });
                                ref.read(quizzesListProvider.notifier).filterSubject('');
                              },
                            );
                          }
                          final s = subjects[i - 1];
                          final sid = s['_id']?.toString() ?? '';
                          final isSel = _selectedSubjectId == sid;
                          IconData chipIcon = Icons.translate_rounded;
                          final name = (s['name'] ?? '').toString().toLowerCase();
                          if (name.contains('comp') || name.contains('code') || name.contains('python')) {
                            chipIcon = Icons.terminal_rounded;
                          } else if (name.contains('algo')) {
                            chipIcon = Icons.account_tree_rounded;
                          }
                          return _QuizSubjectChip(
                            label: s['name'] ?? '',
                            icon: chipIcon,
                            isSelected: isSel,
                            onTap: () {
                              setState(() {
                                _selectedSubjectId = sid;
                                _selectedTopic = '';
                              });
                              ref.read(quizzesListProvider.notifier).filterSubject(sid);
                            },
                          );
                        },
                      ),
                    ),
                  ),

                  // Dynamic Topic Filter Row
                  if (_selectedSubjectId.isNotEmpty)
                    subjectsAsync.maybeWhen(
                      data: (subjects) {
                        final subject = subjects.firstWhere(
                          (s) => s['_id']?.toString() == _selectedSubjectId,
                          orElse: () => {},
                        );
                        final rawTopics = subject['topics'] as List? ?? [];
                        final topics = rawTopics
                            .map((t) => t is Map ? (t['name']?.toString() ?? '') : t.toString())
                            .where((name) => name.trim().isNotEmpty)
                            .toList();

                        if (topics.isEmpty) return const SizedBox.shrink();

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: SizedBox(
                            height: 32,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: topics.length + 1,
                              separatorBuilder: (_, __) => const SizedBox(width: 6),
                              itemBuilder: (_, i) {
                                if (i == 0) {
                                  return _QuizTopicChip(
                                    label: 'All Topics',
                                    isSelected: _selectedTopic.isEmpty,
                                    onTap: () {
                                      setState(() => _selectedTopic = '');
                                      ref.read(quizzesListProvider.notifier).filterTopic('');
                                    },
                                  );
                                }
                                final topic = topics[i - 1];
                                return _QuizTopicChip(
                                  label: topic,
                                  isSelected: _selectedTopic == topic,
                                  onTap: () {
                                    setState(() => _selectedTopic = topic);
                                    ref.read(quizzesListProvider.notifier).filterTopic(topic);
                                  },
                                );
                              },
                            ),
                          ),
                        );
                      },
                      orElse: () => const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Quizzes Feed
            Expanded(
              child: state.isLoading
                  ? const ShimmerListLoader()
                  : state.quizzes.isEmpty
                      ? const EmptyState(
                          emoji: '🧠',
                          title: 'No quizzes found',
                          subtitle: 'Try a different search or filter',
                        )
                      : RefreshIndicator(
                          color: AppColors.primary,
                          backgroundColor: AppColors.surfaceContainerLowest,
                          onRefresh: () => ref.read(quizzesListProvider.notifier).fetch(refresh: true),
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                            physics: const BouncingScrollPhysics(),
                            itemCount: state.quizzes.length + 1 + (state.isLoadingMore ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: 14),
                            itemBuilder: (_, i) {
                              if (i < state.quizzes.length) {
                                final quiz = state.quizzes[i];
                                return _StitchQuizCard(
                                  quiz: quiz,
                                  onTap: () => context.go('/quizzes/${quiz.id}'),
                                );
                              }
                              if (state.isLoadingMore && i == state.quizzes.length) {
                                return const ShimmerCard(height: 160);
                              }
                              // Gamification Micro-Banner at bottom
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: AppColors.secondaryFixed,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.local_fire_department_rounded,
                                              size: 22,
                                              color: AppColors.onSecondaryFixed,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Weekly Kata Challenge',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Complete 2 more to keep your streak!',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '3 / 5',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// Subject Filter Chip
class _QuizSubjectChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuizSubjectChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Topic Filter Chip
class _QuizTopicChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuizTopicChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryContainer : AppColors.surfaceContainer,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.secondaryContainer.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.onSecondaryContainer : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Stitch Quiz Card matching the mockup
class _StitchQuizCard extends StatelessWidget {
  final QuizModel quiz;
  final VoidCallback onTap;

  const _StitchQuizCard({required this.quiz, required this.onTap});

  Color get _difficultyDotColor {
    switch (quiz.difficulty.toLowerCase()) {
      case 'easy':
        return AppColors.success;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.error;
    }
  }

  IconData get _quizIcon {
    final title = quiz.title.toLowerCase();
    if (title.contains('greet') || title.contains('begrüß')) return Icons.waving_hand_rounded;
    if (title.contains('article') || title.contains('grammar') || title.contains('rule')) return Icons.rule_rounded;
    if (title.contains('loop') || title.contains('python') || title.contains('data')) return Icons.data_object_rounded;
    if (title.contains('sprech') || title.contains('phonetic') || title.contains('audio')) return Icons.record_voice_over_rounded;
    return Icons.psychology_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon box (gradient)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.secondaryFixed,
                          AppColors.secondaryContainer.withOpacity(0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondaryContainer.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(_quizIcon, size: 24, color: AppColors.onSecondaryContainer),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Tag pills row
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (quiz.subjectName != null && quiz.subjectName!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainer,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  quiz.subjectName!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            if (quiz.topic != null && quiz.topic!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryFixed,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  quiz.topic!,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSecondaryFixed,
                                  ),
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(9999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _difficultyDotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    quiz.difficulty,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Title
                        Text(
                          quiz.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (quiz.description != null && quiz.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            quiz.description!,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.onSurfaceVariant,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Card Footer Stats & CTA
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow.withOpacity(0.6),
                border: Border(top: BorderSide(color: AppColors.surfaceContainerHigh.withOpacity(0.5))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.help_outline_rounded, size: 14, color: AppColors.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  '${quiz.questions.length} Qs',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(width: 3, height: 3, decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.outlineVariant)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.timer_outlined, size: 14, color: AppColors.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  quiz.timeLimit > 0 ? '${quiz.timeLimit}m' : 'No limit',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.isDark ? AppColors.secondary : AppColors.primary,
                      borderRadius: BorderRadius.circular(9999),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Attempt now',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.isDark ? AppColors.onSecondaryContainer : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: AppColors.isDark ? AppColors.onSecondaryContainer : Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
