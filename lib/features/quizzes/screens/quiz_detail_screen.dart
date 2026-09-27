import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../../../shared/widgets/subject_badge.dart';
import '../providers/quiz_provider.dart';

class QuizDetailScreen extends ConsumerWidget {
  final String quizId;
  const QuizDetailScreen({super.key, required this.quizId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quizAsync = ref.watch(quizDetailProvider(quizId));
    final attemptsAsync = ref.watch(myAttemptsProvider(quizId));

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surfaceColor = isDark ? AppColors.pitchBlackSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.pitchBlackBorder : AppColors.lightBorder;
    final textSecondary = isDark ? AppColors.pitchBlackTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.pitchBlackTextMuted : AppColors.lightTextMuted;

    return quizAsync.when(
      loading: () => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const ShimmerListLoader(count: 3),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: Center(
          child: TextButton(
            onPressed: () => ref.invalidate(quizDetailProvider(quizId)),
            child: const Text('Retry'),
          ),
        ),
      ),
      data: (quiz) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            quiz.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero card
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.psychology_outlined,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      quiz.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: onSurface,
                      ),
                    ),
                    if (quiz.description != null && quiz.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        quiz.description!,
                        style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (quiz.subjectName != null)
                          SubjectBadge(label: quiz.subjectName!),
                        if (quiz.topic != null && quiz.topic!.isNotEmpty)
                          TopicBadge(label: quiz.topic!),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Info grid 2x2
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          icon: '📝',
                          label: 'Questions',
                          value: '${quiz.questions.length}',
                          color: isDark ? AppColors.secondary : AppColors.primary,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textMuted: textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoCard(
                          icon: '⏱',
                          label: 'Time Limit',
                          value: quiz.timeLimit > 0 ? '${quiz.timeLimit} min' : 'No limit',
                          color: AppColors.warning,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textMuted: textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _InfoCard(
                          icon: '🎯',
                          label: 'Pass Score',
                          value: '${quiz.passingScore}%',
                          color: AppColors.success,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textMuted: textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _InfoCard(
                          icon: '🔀',
                          label: 'Shuffle',
                          value: quiz.shuffle ? 'Yes' : 'No',
                          color: AppColors.accent,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                          textMuted: textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // My Attempts
              attemptsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (attempts) {
                  if (attempts.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Previous Attempts',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: onSurface,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => context.push('/quizzes/$quizId/review'),
                            icon: Icon(Icons.analytics_outlined, size: 14, color: isDark ? AppColors.secondary : AppColors.primary),
                            label: Text(
                              'Review Answers',
                              style: GoogleFonts.inter(fontSize: 12, color: isDark ? AppColors.secondary : AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: attempts.take(3).toList().asMap().entries.map((e) {
                          final att = e.value;
                          final passed = att.passed;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => context.push('/quizzes/$quizId/review'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: (passed ? AppColors.success : AppColors.error).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (passed ? AppColors.success : AppColors.error).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Attempt ${e.key + 1} : ${att.percentage.toStringAsFixed(0)}% ${passed ? '✓' : '✗'}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: passed ? AppColors.success : AppColors.error,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 10,
                                    color: passed ? AppColors.success : AppColors.error,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  );
                },
              ),

              // Rules
              GlassCard(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  title: Text(
                    'Quiz Rules',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: onSurface,
                    ),
                  ),
                  iconColor: textSecondary,
                  collapsedIconColor: textSecondary,
                  children: [
                    _RuleTile('Read all questions carefully before answering', textSecondary),
                    _RuleTile('Timer starts as soon as you begin', textSecondary),
                    _RuleTile('The quiz auto-submits when time runs out', textSecondary),
                    _RuleTile('You can retake this quiz anytime', textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Start Quiz
              GradientButton(
                text: 'Start Quiz',
                height: 54,
                icon: Icons.play_arrow_rounded,
                onPressed: () => context.go('/quizzes/$quizId/take'),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'You can retake this quiz anytime',
                  style: GoogleFonts.inter(fontSize: 12, color: textMuted),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color color;
  final Color surfaceColor;
  final Color borderColor;
  final Color textMuted;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.surfaceColor,
    required this.borderColor,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 11, color: textMuted),
          ),
        ],
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  final String text;
  final Color textColor;
  const _RuleTile(this.text, this.textColor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.arrow_right, color: Theme.of(context).brightness == Brightness.dark ? AppColors.secondary : AppColors.primary, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 13, color: textColor),
            ),
          ),
        ],
      ),
    );
  }
}
