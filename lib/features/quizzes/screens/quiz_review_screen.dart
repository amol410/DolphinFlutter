import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../providers/quiz_provider.dart';
import '../data/models/quiz_model.dart';

class QuizReviewScreen extends ConsumerWidget {
  final String quizId;

  const QuizReviewScreen({super.key, required this.quizId});

  String _formatTime(int secs) {
    if (secs <= 0) return '0s';
    final m = secs ~/ 60;
    final s = secs % 60;
    if (m > 0 && s > 0) return '${m}m ${s}s';
    if (m > 0) return '${m}m';
    return '${s}s';
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '';
    try {
      final dt = DateTime.parse(dateVal.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(quizReviewProvider(quizId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Quiz Review',
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
        actions: [
          TextButton.icon(
            onPressed: () => context.pushReplacement('/quizzes/$quizId/take'),
            icon: const Icon(Icons.refresh, size: 16, color: AppColors.primaryLight),
            label: Text(
              'Retake',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: reviewAsync.when(
        loading: () => const ShimmerListLoader(count: 3),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.help_outline_rounded, color: AppColors.textMuted, size: 48),
                const SizedBox(height: 16),
                Text(
                  'No Saved Quiz Review',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You haven\'t completed this quiz yet, or the attempt history is unavailable.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.pushReplacement('/quizzes/$quizId/take'),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Take Quiz Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final attempt = data['attempt'] as Map<String, dynamic>? ?? {};
          final quiz = data['quiz'] as Map<String, dynamic>? ?? {};
          final questions = (data['questions'] as List? ?? []).cast<Map<String, dynamic>>();

          final score = attempt['score'] ?? 0;
          final maxScore = attempt['maxScore'] ?? 0;
          final percentage = ((attempt['percentage'] ?? 0) as num).toDouble();
          final passed = attempt['passed'] ?? false;
          final timeTakenSecs = (attempt['timeTakenSecs'] ?? attempt['timeTaken'] ?? 0) as int;
          final quizTitle = quiz['title'] ?? 'Assessment Review';

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              // ── Score Summary Card ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: passed ? AppColors.success.withOpacity(0.3) : AppColors.error.withOpacity(0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (passed ? AppColors.success : AppColors.error).withOpacity(0.08),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      quizTitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CircularPercentIndicator(
                      radius: 54,
                      lineWidth: 9,
                      percent: (percentage / 100).clamp(0.0, 1.0),
                      center: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${percentage.round()}%',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            passed ? 'PASSED' : 'NEEDS WORK',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              color: passed ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      progressColor: passed ? AppColors.success : AppColors.error,
                      backgroundColor: AppColors.surface2,
                      circularStrokeCap: CircularStrokeCap.round,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ReviewStat(
                          label: 'Score',
                          value: '$score / $maxScore pts',
                          icon: Icons.emoji_events_outlined,
                          color: AppColors.warning,
                        ),
                        _ReviewStat(
                          label: 'Time Taken',
                          value: _formatTime(timeTakenSecs),
                          icon: Icons.timer_outlined,
                          color: AppColors.accent,
                        ),
                        _ReviewStat(
                          label: 'Status',
                          value: passed ? 'Passed' : 'Failed',
                          icon: passed ? Icons.check_circle_outline : Icons.cancel_outlined,
                          color: passed ? AppColors.success : AppColors.error,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Questions Header ──
              Row(
                children: [
                  const Icon(Icons.fact_check_outlined, size: 20, color: AppColors.primaryLight),
                  const SizedBox(width: 8),
                  Text(
                    'Questions Review (${questions.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Question Cards ──
              ...questions.asMap().entries.map((entry) {
                final idx = entry.key;
                final q = entry.value;
                return _QuestionReviewCard(index: idx + 1, data: q);
              }),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ReviewStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _QuestionReviewCard extends StatelessWidget {
  final int index;
  final Map<String, dynamic> data;

  const _QuestionReviewCard({required this.index, required this.data});

  @override
  Widget build(BuildContext context) {
    final text = data['text'] ?? data['question'] ?? '';
    final type = data['type'] ?? 'multiple-choice';
    final isMatchPairs = type == 'match-pairs' || type == 'match_pairs';
    final isCorrect = data['isCorrect'] ?? false;
    final pointsEarned = data['pointsEarned'] ?? (isCorrect ? 1 : 0);
    final explanation = data['explanation'] as String?;
    final code = data['code'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCorrect ? AppColors.success.withOpacity(0.3) : AppColors.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Q# and Correctness Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCorrect ? AppColors.success.withOpacity(0.15) : AppColors.error.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      size: 14,
                      color: isCorrect ? AppColors.success : AppColors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Question $index',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCorrect ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '+$pointsEarned pts',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isCorrect ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Question Prompt
          Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),

          // Code block if present
          if (code != null && code.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                code,
                style: GoogleFonts.firaCode(fontSize: 12, color: const Color(0xFF38BDF8)),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Render options or match-pairs table
          if (isMatchPairs)
            _buildMatchPairsReview(data)
          else
            _buildMcqReview(data),

          // Explanation box
          if (explanation != null && explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: AppColors.primaryLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Explanation',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          explanation,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMcqReview(Map<String, dynamic> data) {
    final options = (data['options'] as List? ?? []).cast<String>();
    final correctIndex = data['correctIndex'] as int?;
    final chosenIndex = data['chosenIndex'] as int? ?? -1;

    return Column(
      children: options.asMap().entries.map((e) {
        final optIdx = e.key;
        final optText = e.value;
        final letter = ['A', 'B', 'C', 'D'][optIdx % 4];

        final isUserPick = optIdx == chosenIndex;
        final isCorrectOpt = optIdx == correctIndex;

        Color borderColor = AppColors.border;
        Color bgColor = AppColors.surface2.withOpacity(0.4);
        Color textColor = Colors.white70;
        IconData? icon;
        Color? iconColor;

        if (isCorrectOpt) {
          borderColor = AppColors.success;
          bgColor = AppColors.success.withOpacity(0.12);
          textColor = Colors.white;
          icon = Icons.check_circle;
          iconColor = AppColors.success;
        } else if (isUserPick) {
          borderColor = AppColors.error;
          bgColor = AppColors.error.withOpacity(0.12);
          textColor = Colors.white;
          icon = Icons.cancel;
          iconColor = AppColors.error;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: (isUserPick || isCorrectOpt) ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCorrectOpt
                      ? AppColors.success
                      : isUserPick
                          ? AppColors.error
                          : AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: (isUserPick || isCorrectOpt) ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  optText,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: (isUserPick || isCorrectOpt) ? FontWeight.w600 : FontWeight.normal,
                    color: textColor,
                  ),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, size: 16, color: iconColor),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMatchPairsReview(Map<String, dynamic> data) {
    final pairs = (data['pairs'] as List? ?? []).cast<Map<String, dynamic>>();
    final submittedMatches = (data['submittedMatches'] as List? ?? []).cast<Map<String, dynamic>>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'PAIRED MATCHES AUDIT',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
        ),
        ...pairs.map((qp) {
          final left = qp['left']?.toString() ?? '';
          final correctRight = qp['right']?.toString() ?? '';

          // Find student's match for this left item
          final studentMatch = submittedMatches.firstWhere(
            (sm) => (sm['left']?.toString() ?? '').trim().toLowerCase() == left.trim().toLowerCase(),
            orElse: () => {'right': '(unmatched)'},
          );
          final studentRight = studentMatch['right']?.toString() ?? '(unmatched)';
          final isPairCorrect = studentRight.trim().toLowerCase() == correctRight.trim().toLowerCase();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPairCorrect ? AppColors.success.withOpacity(0.08) : AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isPairCorrect ? AppColors.success.withOpacity(0.4) : AppColors.error.withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPairCorrect ? Icons.check : Icons.close,
                  size: 16,
                  color: isPairCorrect ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        left,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Your answer: ',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                          ),
                          Expanded(
                            child: Text(
                              studentRight,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isPairCorrect ? AppColors.success : AppColors.error,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (!isPairCorrect) ...[
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Text(
                              'Correct answer: ',
                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
                            ),
                            Expanded(
                              child: Text(
                                correctRight,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.success,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
