import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/subject_badge.dart';
import '../../../shared/widgets/glass_card.dart';
import '../providers/quiz_provider.dart';
import '../data/models/quiz_model.dart';
import '../../notes/screens/notes_screen.dart' show subjectsProvider;

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
    final state = ref.watch(quizzesListProvider);
    final subjectsAsync = ref.watch(subjectsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Quizzes',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (q) {
                    Future.delayed(const Duration(milliseconds: 400), () {
                      if (_searchController.text == q) {
                        ref.read(quizzesListProvider.notifier).search(q);
                      }
                    });
                  },
                  style: GoogleFonts.inter(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search quizzes...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                  ),
                ),
                const SizedBox(height: 10),
                subjectsAsync.when(
                  loading: () => const SizedBox(height: 36),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (subjects) => SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: subjects.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return _Chip(
                            label: 'All',
                            selected: _selectedSubjectId.isEmpty,
                            onTap: () {
                              setState(() { _selectedSubjectId = ''; _selectedTopic = ''; });
                              ref.read(quizzesListProvider.notifier).filterSubject('');
                            },
                          );
                        }
                        final s = subjects[i - 1];
                        final sid = s['_id']?.toString() ?? '';
                        return _Chip(
                          label: s['name'] ?? '',
                          selected: _selectedSubjectId == sid,
                          onTap: () {
                            setState(() { _selectedSubjectId = sid; _selectedTopic = ''; });
                            ref.read(quizzesListProvider.notifier).filterSubject(sid);
                          },
                        );
                      },
                    ),
                  ),
                ),
                // Topic chips (when a subject is selected)
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
                            itemCount: topics.length + 1,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              if (i == 0) {
                                return _Chip(
                                  label: 'All Topics',
                                  selected: _selectedTopic.isEmpty,
                                  isAccent: true,
                                  onTap: () {
                                    setState(() => _selectedTopic = '');
                                    ref.read(quizzesListProvider.notifier).filterTopic('');
                                  },
                                );
                              }
                              final topic = topics[i - 1];
                              return _Chip(
                                label: topic,
                                selected: _selectedTopic == topic,
                                isAccent: true,
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
                        backgroundColor: AppColors.surface,
                        onRefresh: () =>
                            ref.read(quizzesListProvider.notifier).fetch(refresh: true),
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: state.quizzes.length + (state.isLoadingMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i >= state.quizzes.length) return const ShimmerCard(height: 160);
                            return QuizCard(
                              quiz: state.quizzes[i],
                              onTap: () => context.go('/quizzes/${state.quizzes[i].id}'),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isAccent;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isAccent = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (isAccent ? const Color(0xFF06B6D4) : AppColors.primary)
              : AppColors.surface2,
          borderRadius: BorderRadius.circular(20),
          border: isAccent && selected
              ? Border.all(color: const Color(0xFF67E8F9), width: 1)
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isAccent ? 12 : 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class QuizCard extends StatelessWidget {
  final QuizModel quiz;
  final VoidCallback onTap;
  const QuizCard({super.key, required this.quiz, required this.onTap});

  Color get _difficultyColor {
    switch (quiz.difficulty) {
      case 'Easy': return AppColors.success;
      case 'Medium': return AppColors.warning;
      default: return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.psychology_outlined,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (quiz.subjectName != null) SubjectBadge(label: quiz.subjectName!),
                    if (quiz.topic != null && quiz.topic!.isNotEmpty)
                      TopicBadge(label: quiz.topic!),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _difficultyColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(quiz.difficulty,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _difficultyColor,
                  )),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(quiz.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
          if (quiz.description != null && quiz.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(quiz.description!,
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textSecondary),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.quiz_outlined, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('${quiz.questions.length} questions',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(width: 8),
              Container(width: 3, height: 3, decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.textMuted)),
              const SizedBox(width: 8),
              const Icon(Icons.check_circle_outline, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text('Pass: ${quiz.passingScore}%',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
              if (quiz.timeLimit > 0) ...[
                const SizedBox(width: 8),
                Container(width: 3, height: 3, decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.textMuted)),
                const SizedBox(width: 8),
                const Icon(Icons.timer_outlined, size: 13, color: AppColors.warning),
                const SizedBox(width: 3),
                Text('${quiz.timeLimit}m',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.warning)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          GradientButton(text: 'Take Quiz', height: 44, onPressed: onTap),
        ],
      ),
    );
  }
}
