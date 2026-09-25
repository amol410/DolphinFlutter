import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../data/models/quiz_model.dart';
import '../providers/quiz_provider.dart';

class QuizResultScreen extends ConsumerWidget {
  final String quizId;
  final Map<String, dynamic> result;

  const QuizResultScreen({super.key, required this.quizId, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read from provider first (set during submission), then fall back
    // to route extra. The provider is set before navigation in _submit().
    final cached = ref.watch(quizResultProvider(quizId));
    final hasCached = cached != null && cached.isNotEmpty;
    final hasRoute = result.isNotEmpty;
    final data = hasCached ? cached! : result;

    // If neither source has data, show an error state
    if (!hasCached && !hasRoute) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text('Quiz Results',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.textMuted, size: 48),
              const SizedBox(height: 16),
              Text('No result data available.',
                style: GoogleFonts.inter(fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => context.go('/quizzes'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.textMuted),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Back to Quizzes',
                  style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Quiz Results',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Score hero
            GlassCard(
              child: Column(
                children: [
                  CircularPercentIndicator(
                    radius: 70,
                    lineWidth: 10,
                    percent: (percentage / 100).clamp(0.0, 1.0),
                    progressColor: ringColor,
                    backgroundColor: ringColor.withOpacity(0.15),
                    animation: true,
                    animationDuration: 1200,
                    center: Text(
                      '${percentage.toStringAsFixed(0)}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: ringColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: ringColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: ringColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      passed ? '🎉  PASSED' : '✗  FAILED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ringColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$score / $maxScore points',
                    style: GoogleFonts.inter(
                      fontSize: 15, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Stats row
            Row(
              children: [
                _StatMini(value: '$correct', label: 'Correct', color: AppColors.success,
                    icon: Icons.check_circle_outline),
                const SizedBox(width: 8),
                _StatMini(value: '$wrong', label: 'Wrong', color: AppColors.error,
                    icon: Icons.cancel_outlined),
                const SizedBox(width: 8),
                _StatMini(value: '$skipped', label: 'Skipped', color: AppColors.textMuted,
                    icon: Icons.remove_circle_outline),
                const SizedBox(width: 8),
                _StatMini(value: formatTime(timeTaken), label: 'Time',
                    color: AppColors.primary, icon: Icons.timer_outlined),
              ],
            ),
            const SizedBox(height: 20),

            // Question review
            if (questions.isNotEmpty && answers.isNotEmpty) ...[
              Text('Review Answers',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: answers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final answer = answers[i];
                  final isCorrect = answer is AttemptAnswer ? answer.correct
                      : (answer is Map ? answer['correct'] == true : false);
                  final isSkipped = answer is AttemptAnswer
                      ? answer.selectedIndex == -1
                      : (answer is Map ? (answer['selectedIndex'] ?? -1) == -1 : false);
                  final selectedIdx = answer is AttemptAnswer ? answer.selectedIndex
                      : (answer is Map ? (answer['selectedIndex'] ?? -1) as int : -1);
                  final correctIdx = answer is AttemptAnswer ? answer.correctIndex
                      : (answer is Map ? (answer['correctIndex'] ?? 0) as int : 0);
                  final explanation = answer is AttemptAnswer ? answer.explanation
                      : (answer is Map ? answer['explanation'] as String? : null);

                  QuizQuestion? question;
                  if (i < questions.length && questions[i] is QuizQuestion) {
                    question = questions[i] as QuizQuestion;
                  }

                  final borderColor = isSkipped
                      ? AppColors.textMuted
                      : isCorrect
                          ? AppColors.success
                          : AppColors.error;

                  // Status label + icon for the top-right badge
                  final statusLabel = isSkipped ? 'Skipped'
                      : isCorrect ? 'Correct' : 'Wrong';
                  final statusColor = isSkipped ? AppColors.textMuted
                      : isCorrect ? AppColors.success : AppColors.error;
                  final statusIcon = isSkipped ? Icons.remove_circle_outline
                      : isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined;

                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border(left: BorderSide(color: borderColor, width: 4)),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Question number + status badge row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('Q${i + 1}',
                                style: GoogleFonts.inter(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                            ),
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, color: statusColor, size: 15),
                                const SizedBox(width: 4),
                                Text(statusLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: statusColor)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Full question text — no line clamp
                        Text(
                          question?.text ?? 'Question ${i + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15, fontWeight: FontWeight.w600,
                            color: Colors.white, height: 1.45),
                        ),
                        const SizedBox(height: 10),

                        // Divider
                        Divider(color: AppColors.border, height: 1),
                        const SizedBox(height: 10),

                        // Your answer (if answered)
                        if (!isSkipped && question != null &&
                            selectedIdx >= 0 && selectedIdx < question.options.length) ...[
                          _AnswerRow(
                            label: 'Your answer',
                            text: question.options[selectedIdx],
                            color: isCorrect ? AppColors.success : AppColors.error,
                            icon: isCorrect ? Icons.check_circle : Icons.cancel,
                          ),
                          const SizedBox(height: 6),
                        ],

                        // Skipped label
                        if (isSkipped) ...[
                          Row(
                            children: [
                              Icon(Icons.remove_circle_outline,
                                  color: AppColors.textMuted, size: 16),
                              const SizedBox(width: 6),
                              Text('Not answered (Skipped)',
                                style: GoogleFonts.inter(
                                  fontSize: 14, color: AppColors.textMuted,
                                  fontStyle: FontStyle.italic)),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],

                        // Always show correct answer for wrong or skipped
                        if ((!isCorrect || isSkipped) && question != null &&
                            correctIdx < question.options.length) ...[
                          _AnswerRow(
                            label: 'Correct answer',
                            text: question.options[correctIdx],
                            color: AppColors.success,
                            icon: Icons.check_circle,
                          ),
                          const SizedBox(height: 6),
                        ],

                        // Explanation — always visible, no accordion
                        if (explanation != null && explanation.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.lightbulb_outline,
                                      color: AppColors.warning, size: 15),
                                    const SizedBox(width: 6),
                                    Text('Explanation',
                                      style: GoogleFonts.inter(
                                        fontSize: 13, fontWeight: FontWeight.w600,
                                        color: AppColors.warning)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(explanation,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                    height: 1.5)),
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
              label: Text('Review Questions & Answers',
                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.primaryLight,
                side: const BorderSide(color: AppColors.primary, width: 1.5),
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
                side: const BorderSide(color: AppColors.textMuted),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Back to Quizzes',
                style: GoogleFonts.inter(
                  fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
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

  const _StatMini({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            Text(label,
              style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

/// A labelled answer row used in the review section.
/// Shows [label] (e.g. "Your answer" / "Correct answer") with an icon
/// and the option [text] in the appropriate [color].
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
