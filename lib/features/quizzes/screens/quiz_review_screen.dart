import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../providers/quiz_provider.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(quizReviewProvider(quizId));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surfaceColor = isDark ? AppColors.pitchBlackSurface : AppColors.lightSurface;
    final surface2Color = isDark ? AppColors.pitchBlackSurface2 : AppColors.lightSurface2;
    final borderColor = isDark ? AppColors.pitchBlackBorder : AppColors.lightBorder;
    final textSecondary = isDark ? AppColors.pitchBlackTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.pitchBlackTextMuted : AppColors.lightTextMuted;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Quiz Review',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
        ),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => context.pushReplacement('/quizzes/$quizId/take'),
            icon: Icon(Icons.refresh, size: 16, color: onSurface),
            label: Text(
              'Retake',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: onSurface,
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
                Icon(Icons.help_outline_rounded, color: AppColors.textMuted, size: 48),
                const SizedBox(height: 16),
                Text(
                  'No Saved Quiz Review',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You haven\'t completed this quiz yet, or the attempt history is unavailable.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.pushReplacement('/quizzes/$quizId/take'),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Take Quiz Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.secondary : AppColors.primary,
                    foregroundColor: isDark ? AppColors.onSecondaryContainer : Colors.white,
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
            padding: const EdgeInsets.all(16),
            children: [
              // ── Summary Score Card ──
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceColor,
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
                        color: onSurface,
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
                              color: onSurface,
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
                      backgroundColor: surface2Color,
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
                          onSurface: onSurface,
                          textMuted: textMuted,
                        ),
                        _ReviewStat(
                          label: 'Time Taken',
                          value: _formatTime(timeTakenSecs),
                          icon: Icons.timer_outlined,
                          color: AppColors.accent,
                          onSurface: onSurface,
                          textMuted: textMuted,
                        ),
                        _ReviewStat(
                          label: 'Status',
                          value: passed ? 'Passed' : 'Failed',
                          icon: passed ? Icons.check_circle_outline : Icons.cancel_outlined,
                          color: passed ? AppColors.success : AppColors.error,
                          onSurface: onSurface,
                          textMuted: textMuted,
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
                  Icon(Icons.fact_check_outlined, size: 20, color: isDark ? AppColors.secondary : AppColors.primaryLight),
                  const SizedBox(width: 8),
                  Text(
                    'Questions Review (${questions.length})',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
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
  final Color onSurface;
  final Color textMuted;

  const _ReviewStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.onSurface,
    required this.textMuted,
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
            color: onSurface,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: textMuted,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surfaceColor = isDark ? AppColors.pitchBlackSurface : AppColors.lightSurface;
    final surface2Color = isDark ? AppColors.pitchBlackSurface2 : AppColors.lightSurface2;
    final borderColor = isDark ? AppColors.pitchBlackBorder : AppColors.lightBorder;
    final textMuted = isDark ? AppColors.pitchBlackTextMuted : AppColors.lightTextMuted;

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
        color: surfaceColor,
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
                  color: isCorrect ? AppColors.success : textMuted,
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
              color: onSurface,
            ),
          ),

          // Code block if present
          if (code != null && code.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? surface2Color : const Color(0xFF1E293B),
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
            _buildMatchPairsReview(data, onSurface, textMuted)
          else
            _buildMcqReview(data, isDark, onSurface, surfaceColor, surface2Color, borderColor),

          // Explanation box
          if (explanation != null && explanation.trim().isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? AppColors.secondary : AppColors.primary).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: (isDark ? AppColors.secondary : AppColors.primary).withOpacity(0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline, size: 16, color: isDark ? AppColors.secondary : AppColors.primaryLight),
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
                            color: isDark ? AppColors.secondary : AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          explanation,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: onSurface.withOpacity(0.85),
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

  Widget _buildMcqReview(
    Map<String, dynamic> data,
    bool isDark,
    Color onSurface,
    Color surfaceColor,
    Color surface2Color,
    Color defaultBorderColor,
  ) {
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

        Color itemBorderColor = defaultBorderColor;
        Color bgColor = surface2Color.withOpacity(0.5);
        Color textColor = onSurface.withOpacity(0.8);
        IconData? icon;
        Color? iconColor;

        if (isCorrectOpt) {
          itemBorderColor = AppColors.success;
          bgColor = AppColors.success.withOpacity(0.12);
          textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
          icon = Icons.check_circle;
          iconColor = AppColors.success;
        } else if (isUserPick) {
          itemBorderColor = AppColors.error;
          bgColor = AppColors.error.withOpacity(0.12);
          textColor = isDark ? Colors.white : AppColors.lightTextPrimary;
          icon = Icons.cancel;
          iconColor = AppColors.error;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: itemBorderColor, width: (isUserPick || isCorrectOpt) ? 1.5 : 1),
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
                          : surfaceColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: (isUserPick || isCorrectOpt)
                          ? Colors.white
                          : (isDark ? AppColors.pitchBlackTextSecondary : AppColors.lightTextSecondary),
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

  Widget _buildMatchPairsReview(Map<String, dynamic> data, Color onSurface, Color textMuted) {
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
              color: textMuted,
            ),
          ),
        ),
        ...pairs.map((qp) {
          final left = qp['left']?.toString() ?? '';
          final correctRight = qp['right']?.toString() ?? '';

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
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            'Your answer: ',
                            style: GoogleFonts.inter(fontSize: 11, color: textMuted),
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
                              style: GoogleFonts.inter(fontSize: 11, color: textMuted),
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
