import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../flashcards/providers/difficult_words_provider.dart';
import '../data/models/quiz_model.dart';
import '../providers/quiz_provider.dart';

class QuizResultScreen extends ConsumerWidget {
  final String quizId;
  final Map<String, dynamic> result;

  const QuizResultScreen({super.key, required this.quizId, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final difficultWordsState = ref.watch(difficultWordsProvider);
    final cached = ref.watch(quizResultProvider(quizId));
    final hasCached = cached != null && cached.isNotEmpty;
    final hasRoute = result.isNotEmpty;
    final data = hasCached ? cached! : result;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surfaceColor = isDark ? AppColors.pitchBlackSurface : AppColors.lightSurface;
    final surface2Color = isDark ? AppColors.pitchBlackSurface2 : AppColors.lightSurface2;
    final borderColor = isDark ? AppColors.pitchBlackBorder : AppColors.lightBorder;
    final textSecondary = isDark ? AppColors.pitchBlackTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.pitchBlackTextMuted : AppColors.lightTextMuted;

    // If neither source has data, show an error state
    if (!hasCached && !hasRoute) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(
            'Quiz Results',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: onSurface,
            ),
          ),
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: AppColors.textMuted, size: 48),
              const SizedBox(height: 16),
              Text(
                'No result data available.',
                style: GoogleFonts.inter(fontSize: 16, color: textSecondary),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => context.go('/quizzes'),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderColor),
                  foregroundColor: onSurface,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Back to Quizzes',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: onSurface),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final score = data['score'] as int? ?? 0;
    final maxScore = data['maxScore'] as int? ?? 0;
    final percentage = (data['percentage'] as num?)?.toDouble() ?? 0.0;
    final passed = data['passed'] as bool? ?? false;
    final timeTaken = data['timeTaken'] as int? ?? 0;
    final answers = data['answers'] as List? ?? [];
    final questions = data['questions'] as List? ?? [];

    final ringColor = passed ? AppColors.success : AppColors.error;
    int correct = 0, wrong = 0, skipped = 0;
    for (final a in answers) {
      if (a is AttemptAnswer) {
        if (a.selectedIndex == -1) skipped++;
        else if (a.correct) correct++;
        else wrong++;
      } else if (a is Map) {
        if ((a['selectedIndex'] ?? -1) == -1) skipped++;
        else if (a['correct'] == true) correct++;
        else wrong++;
      }
    }

    String formatTime(int s) {
      final m = s ~/ 60;
      final sec = s % 60;
      return '${m}m ${sec}s';
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Quiz Results',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Score card
            GlassCard(
              child: Column(
                children: [
                  CircularPercentIndicator(
                    radius: 65,
                    lineWidth: 10,
                    percent: (percentage / 100).clamp(0.0, 1.0),
                    progressColor: ringColor,
                    backgroundColor: ringColor.withOpacity(0.15),
                    circularStrokeCap: CircularStrokeCap.round,
                    center: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${percentage.round()}%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: ringColor,
                          ),
                        ),
                        Text(
                          '$score / $maxScore',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    passed ? '🎉 Congratulations!' : 'Keep Practicing!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    passed
                        ? 'You have passed this quiz successfully!'
                        : 'Review your mistakes and try again.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 15, color: textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats row
            Row(
              children: [
                _StatMini(
                  value: '$correct',
                  label: 'Correct',
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textMuted: textMuted,
                ),
                const SizedBox(width: 8),
                _StatMini(
                  value: '$wrong',
                  label: 'Wrong',
                  color: AppColors.error,
                  icon: Icons.cancel_outlined,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textMuted: textMuted,
                ),
                const SizedBox(width: 8),
                _StatMini(
                  value: '$skipped',
                  label: 'Skipped',
                  color: textMuted,
                  icon: Icons.remove_circle_outline,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textMuted: textMuted,
                ),
                const SizedBox(width: 8),
                _StatMini(
                  value: formatTime(timeTaken),
                  label: 'Time',
                  color: isDark ? AppColors.secondary : AppColors.primary,
                  icon: Icons.timer_outlined,
                  surfaceColor: surfaceColor,
                  borderColor: borderColor,
                  textMuted: textMuted,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Question review
            if (questions.isNotEmpty && answers.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Review Answers',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: answers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final answer = answers[i];
                  final isCorrect = answer is AttemptAnswer
                      ? answer.correct
                      : (answer is Map ? answer['correct'] == true : false);
                  final isSkipped = answer is AttemptAnswer
                      ? answer.selectedIndex == -1
                      : (answer is Map ? (answer['selectedIndex'] ?? -1) == -1 : false);
                  final selectedIdx = answer is AttemptAnswer
                      ? answer.selectedIndex
                      : (answer is Map ? (answer['selectedIndex'] ?? -1) as int : -1);
                  final correctIdx = answer is AttemptAnswer
                      ? answer.correctIndex
                      : (answer is Map ? (answer['correctIndex'] ?? 0) as int : 0);
                  final explanation = answer is AttemptAnswer
                      ? answer.explanation
                      : (answer is Map ? answer['explanation'] as String? : null);

                  QuizQuestion? question;
                  if (i < questions.length && questions[i] is QuizQuestion) {
                    question = questions[i] as QuizQuestion;
                  }

                  final itemBorderColor = isSkipped
                      ? textMuted
                      : isCorrect
                          ? AppColors.success
                          : AppColors.error;

                  final statusLabel = isSkipped ? 'Skipped' : isCorrect ? 'Correct' : 'Wrong';
                  final statusColor = isSkipped ? textMuted : isCorrect ? AppColors.success : AppColors.error;
                  final statusIcon = isSkipped
                      ? Icons.remove_circle_outline
                      : isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined;

                  String cardFront = '';
                  String cardBack = '';
                  if (question != null) {
                    cardFront = question.text;
                    if (correctIdx >= 0 && correctIdx < question.options.length) {
                      cardBack = question.options[correctIdx];
                    }
                    if (explanation != null && explanation.trim().isNotEmpty) {
                      cardBack = cardBack.isEmpty ? explanation : '$cardBack\n\n💡 $explanation';
                    }
                  } else if (answer is Map) {
                    cardFront = (answer['questionText'] ?? 'Question ${i + 1}').toString();
                    cardBack = (answer['correctAnswer'] ?? answer['explanation'] ?? '').toString();
                  }

                  final isStarred = cardFront.isNotEmpty && difficultWordsState.isBookmarked(cardFront);

                  return Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border(left: BorderSide(color: itemBorderColor, width: 4)),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: (isDark ? AppColors.secondary : AppColors.primary).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Q${i + 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.secondary : AppColors.primary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: statusColor, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  statusLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ],
                            ),
                            if (cardFront.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: () async {
                                  final msg = await ref
                                      .read(difficultWordsProvider.notifier)
                                      .toggleBookmark(
                                        front: cardFront,
                                        back: cardBack,
                                        hint: 'Quiz Revision',
                                      );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          msg,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                        duration: const Duration(seconds: 2),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Icon(
                                    isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                                    color: isStarred ? const Color(0xFFFFB800) : textMuted,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 10),

                        Text(
                          question?.text ?? 'Question ${i + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: onSurface,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 10),

                        Divider(color: borderColor, height: 1),
                        const SizedBox(height: 10),

                        if (!isSkipped &&
                            question != null &&
                            selectedIdx >= 0 &&
                            selectedIdx < question.options.length) ...[
                          _AnswerRow(
                            label: 'Your answer',
                            text: question.options[selectedIdx],
                            color: isCorrect ? AppColors.success : AppColors.error,
                            icon: isCorrect ? Icons.check_circle : Icons.cancel,
                          ),
                          const SizedBox(height: 6),
                        ],

                        if (isSkipped) ...[
                          Row(
                            children: [
                              Icon(Icons.remove_circle_outline, color: textMuted, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Not answered (Skipped)',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: textMuted,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],

                        if ((!isCorrect || isSkipped) &&
                            question != null &&
                            correctIdx < question.options.length) ...[
                          _AnswerRow(
                            label: 'Correct answer',
                            text: question.options[correctIdx],
                            color: AppColors.success,
                            icon: Icons.check_circle,
                          ),
                          const SizedBox(height: 6),
                        ],

                        if (explanation != null && explanation.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: surface2Color,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.lightbulb_outline, color: AppColors.warning, size: 15),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Explanation',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.warning,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  explanation,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],

            // Action buttons
            ElevatedButton.icon(
              onPressed: () => context.push('/quizzes/$quizId/review'),
              icon: const Icon(Icons.fact_check_outlined, size: 18),
              label: Text(
                'Review Questions & Answers',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: surfaceColor,
                foregroundColor: onSurface,
                side: BorderSide(color: isDark ? AppColors.secondary : AppColors.primary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            GradientButton(
              text: 'Retake Quiz',
              icon: Icons.replay,
              onPressed: () => context.go('/quizzes/$quizId/take'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.go('/quizzes'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: borderColor),
                foregroundColor: onSurface,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Back to Quizzes',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: onSurface),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final IconData icon;
  final Color surfaceColor;
  final Color borderColor;
  final Color textMuted;

  const _StatMini({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
    required this.surfaceColor,
    required this.borderColor,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 10, color: textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  final String label;
  final String text;
  final Color color;
  final IconData icon;

  const _AnswerRow({
    required this.label,
    required this.text,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                TextSpan(
                  text: text,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: color,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
