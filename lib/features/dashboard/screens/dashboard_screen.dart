import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/subject_badge.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../auth/providers/auth_provider.dart';
import '../../notes/providers/notes_provider.dart';
import '../../videos/providers/videos_provider.dart';
import '../../quizzes/providers/quiz_provider.dart';
import '../../flashcards/providers/flashcard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final notesState = ref.watch(notesListProvider);
    final videosState = ref.watch(videosListProvider);
    final quizzesState = ref.watch(quizzesListProvider);
    final decksAsync = ref.watch(flashcardListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            expandedHeight: 120,
            backgroundColor: AppColors.background,
            flexibleSpace: FlexibleSpaceBar(
              background: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_greeting()}, ${user?.name.split(' ').first ?? 'Learner'} 👋',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Ready to learn today?',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                        ),
                        child: Center(
                          child: Text(
                            user?.initials ?? 'DC',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ── Stats Row ──
                  SizedBox(
                    height: 90,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _StatCard(icon: '📝', label: 'Notes',
                            count: notesState.notes.length, color: AppColors.noteBlue),
                        _StatCard(icon: '🎬', label: 'Videos',
                            count: videosState.videos.length, color: AppColors.warning),
                        _StatCard(icon: '🧠', label: 'Quizzes',
                            count: quizzesState.quizzes.length, color: AppColors.accent),
                        _StatCard(icon: '🃏', label: 'Decks',
                            count: decksAsync.valueOrNull?.length ?? 0, color: AppColors.success),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Recent Notes ──
                  _SectionHeader(title: '📚 Recent Notes', onViewAll: () => context.go('/notes')),
                  const SizedBox(height: 12),
                  if (notesState.isLoading)
                    const ShimmerCard(height: 110)
                  else if (notesState.notes.isEmpty)
                    _EmptySection(message: 'No notes yet')
                  else
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: notesState.notes.take(5).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, i) {
                          final note = notesState.notes[i];
                          return GestureDetector(
                            onTap: () => context.go('/notes/${note.id}'),
                            child: Container(
                              width: 200,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border(
                                  left: BorderSide(
                                    color: AppColors.noteColorFromString(note.color),
                                    width: 3,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(note.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  if (note.subjectName != null)
                                    SubjectBadge(label: note.subjectName!),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),

                  // ── Featured Quiz ──
                  _SectionHeader(title: '🧠 Featured Quiz', onViewAll: () => context.go('/quizzes')),
                  const SizedBox(height: 12),
                  if (quizzesState.isLoading)
                    const ShimmerCard(height: 140)
                  else if (quizzesState.quizzes.isEmpty)
                    _EmptySection(message: 'No quizzes yet')
                  else
                    _QuizCard(quiz: quizzesState.quizzes.first, onTap: () =>
                        context.go('/quizzes/${quizzesState.quizzes.first.id}')),
                  const SizedBox(height: 24),

                  // ── Latest Video ──
                  _SectionHeader(title: '🎬 Latest Video', onViewAll: () => context.go('/videos')),
                  const SizedBox(height: 12),
                  if (videosState.isLoading)
                    const ShimmerCard(height: 180)
                  else if (videosState.videos.isEmpty)
                    _EmptySection(message: 'No videos yet')
                  else
                    _VideoCard(video: videosState.videos.first,
                        onTap: () => context.go('/videos/${videosState.videos.first.id}')),
                  const SizedBox(height: 24),

                  // ── Flashcard Decks ──
                  _SectionHeader(title: '🃏 Flashcard Decks', onViewAll: () => context.go('/flashcards')),
                  const SizedBox(height: 12),
                  decksAsync.when(
                    loading: () => const ShimmerCard(height: 100),
                    error: (_, __) => _EmptySection(message: 'Could not load decks'),
                    data: (decks) => decks.isEmpty
                        ? _EmptySection(message: 'No decks yet')
                        : SizedBox(
                            height: 110,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: decks.take(4).length,
                              separatorBuilder: (_, __) => const SizedBox(width: 12),
                              itemBuilder: (_, i) {
                                final deck = decks[i];
                                final colors = AppColors.deckGradientFromString(deck.color);
                                return GestureDetector(
                                  onTap: () => context.go('/flashcards/${deck.id}/study'),
                                  child: Container(
                                    width: 160,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: colors,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(Icons.style, color: Colors.white, size: 24),
                                        const Spacer(),
                                        Text(deck.deckName,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text('${deck.cardCount} cards',
                                          style: GoogleFonts.inter(
                                              fontSize: 11, color: Colors.white70)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final int count;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(height: 4),
          Text('$count',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(label,
            style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;
  const _SectionHeader({required this.title, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
        const Spacer(),
        TextButton(
          onPressed: onViewAll,
          child: Text('View All', style: GoogleFonts.inter(
            fontSize: 13, color: AppColors.textSecondary)),
        ),
      ],
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String message;
  const _EmptySection({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      alignment: Alignment.center,
      child: Text(message, style: GoogleFonts.inter(color: AppColors.textMuted)),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final dynamic quiz;
  final VoidCallback onTap;
  const _QuizCard({required this.quiz, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
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
                child: const Icon(Icons.psychology_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (quiz.subjectName != null) SubjectBadge(label: quiz.subjectName),
                    const SizedBox(height: 4),
                    Text(quiz.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.quiz_outlined, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${quiz.questions.length} questions',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              const Icon(Icons.check_circle_outline, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('Pass: ${quiz.passingScore}%',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          GradientButton(text: 'Take Quiz', height: 40, onPressed: onTap),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final dynamic video;
  final VoidCallback onTap;
  const _VideoCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(color: AppColors.surface2),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Colors.black54],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  const Center(
                    child: Icon(Icons.play_circle_filled,
                      color: Colors.white, size: 48),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(video.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
