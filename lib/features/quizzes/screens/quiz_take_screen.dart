import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../providers/quiz_provider.dart';
import '../data/models/quiz_model.dart';
import 'widgets/match_pairs_widget.dart';

class QuizTakeScreen extends ConsumerStatefulWidget {
  final String quizId;
  const QuizTakeScreen({super.key, required this.quizId});

  @override
  ConsumerState<QuizTakeScreen> createState() => _QuizTakeScreenState();
}

class _QuizTakeScreenState extends ConsumerState<QuizTakeScreen> {
  Timer? _timer;
  QuizModel? _quiz;
  int _startTime = 0;

  @override
  void initState() {
    super.initState();
    _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    final quiz = await ref.read(quizRepositoryProvider).getQuizById(widget.quizId);
    if (!mounted) return;
    setState(() => _quiz = quiz);
    ref.read(quizTakeProvider.notifier).init(quiz.timeLimit);
    if (quiz.timeLimit > 0) _startTimer();
    _startTime = DateTime.now().millisecondsSinceEpoch;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final state = ref.read(quizTakeProvider);
      if (state.secondsRemaining <= 1) {
        _timer?.cancel();
        _submit(autoSubmit: true);
      } else {
        ref.read(quizTakeProvider.notifier).tick();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _submit({bool autoSubmit = false}) async {
    final quiz = _quiz;
    if (quiz == null) return;
    if (ref.read(quizTakeProvider).isSubmitting) return;

    final qState = ref.read(quizTakeProvider);
    int answeredCount = 0;
    for (final q in quiz.questions) {
      if (q.isMatchPairs) {
        final matches = qState.matchAnswers[q.id];
        if (matches != null && matches.any((m) => (m['right'] ?? '').isNotEmpty)) {
          answeredCount++;
        }
      } else {
        if (qState.selectedAnswers.containsKey(q.id)) {
          answeredCount++;
        }
      }
    }
    final unanswered = quiz.questions.length - answeredCount;

    if (!autoSubmit && unanswered > 0) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final surfaceColor = isDark ? AppColors.pitchBlackSurface : AppColors.lightSurface;
      final onSurface = Theme.of(context).colorScheme.onSurface;
      final textSecondary = isDark ? AppColors.pitchBlackTextSecondary : AppColors.lightTextSecondary;

      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Submit Quiz?',
            style: GoogleFonts.plusJakartaSans(color: onSurface, fontWeight: FontWeight.w600),
          ),
          content: Text(
            'You have $unanswered unanswered question${unanswered > 1 ? 's' : ''}. Submit anyway?',
            style: GoogleFonts.inter(color: textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel', style: GoogleFonts.inter(color: textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Submit', style: GoogleFonts.inter(color: AppColors.error, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    _timer?.cancel();
    _timer = null;

    ref.read(quizTakeProvider.notifier).setSubmitting(true);
    try {
      final answers = quiz.questions.map((q) {
        if (q.isMatchPairs) {
          return {
            'questionId': q.id,
            'matches': qState.matchAnswers[q.id] ?? [],
          };
        }
        return {
          'questionId': q.id,
          'chosenIndex': qState.selectedAnswers[q.id] ?? -1,
        };
      }).toList();
      final timeTaken = ((DateTime.now().millisecondsSinceEpoch - _startTime) / 1000).round();
      final result = await ref.read(quizRepositoryProvider).submitAttempt(
        widget.quizId,
        answers,
        timeTaken,
      );
      if (!mounted) return;

      final resultData = <String, dynamic>{
        'score': result.score,
        'maxScore': result.maxScore,
        'percentage': result.percentage,
        'passed': result.passed,
        'answers': result.answers,
        'timeTaken': timeTaken,
        'questions': quiz.questions,
      };

      ref.read(quizResultProvider(widget.quizId).notifier).state = resultData;

      context.pushReplacement(
        '/quizzes/${widget.quizId}/result',
        extra: resultData,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
      ref.read(quizTakeProvider.notifier).setSubmitting(false);
    }
  }

  void _openNavigator() {
    final quiz = _quiz;
    if (quiz == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.pitchBlackSurface : AppColors.lightSurface;

    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _QuestionNavigatorSheet(
        quiz: quiz,
        onSelect: (i) {
          Navigator.pop(sheetContext);
          ref.read(quizTakeProvider.notifier).goTo(i);
        },
        onSubmit: () {
          Navigator.pop(sheetContext);
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _submit();
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final qState = ref.watch(quizTakeProvider);
    final quiz = _quiz;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surfaceColor = isDark ? AppColors.pitchBlackSurface : AppColors.lightSurface;
    final surface2Color = isDark ? AppColors.pitchBlackSurface2 : AppColors.lightSurface2;
    final borderColor = isDark ? AppColors.pitchBlackBorder : AppColors.lightBorder;
    final textSecondary = isDark ? AppColors.pitchBlackTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.pitchBlackTextMuted : AppColors.lightTextMuted;

    if (quiz == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final question = quiz.questions[qState.currentIndex];
    final total = quiz.questions.length;
    final progress = (qState.currentIndex + 1) / total;
    final isLast = qState.currentIndex == total - 1;
    final secondsRemaining = qState.secondsRemaining;
    final timerColor = secondsRemaining <= 60 ? AppColors.error : AppColors.success;

    String formatTime(int s) {
      final m = s ~/ 60;
      final sec = s % 60;
      return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/quizzes/${widget.quizId}'),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: surface2Color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.close, color: onSurface, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      quiz.title,
                      style: GoogleFonts.inter(fontSize: 14, color: onSurface, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (quiz.timeLimit > 0)
                    CircularPercentIndicator(
                      radius: 28,
                      lineWidth: 3,
                      percent: (quiz.timeLimit * 60 > 0) ? (secondsRemaining / (quiz.timeLimit * 60)).clamp(0.0, 1.0) : 0.0,
                      progressColor: timerColor,
                      backgroundColor: timerColor.withOpacity(0.15),
                      center: Text(
                        formatTime(secondsRemaining),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: timerColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    color: isDark ? AppColors.secondary : AppColors.primary,
                    backgroundColor: surface2Color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Q${qState.currentIndex + 1} of $total',
                    style: GoogleFonts.inter(fontSize: 12, color: textMuted),
                  ),
                ],
              ),
            ),

            // Question Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Question card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isDark ? AppColors.secondary : AppColors.primary).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Q${qState.currentIndex + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.secondary : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            question.text,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (question.code != null && question.code!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? surface2Color : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          question.code!,
                          style: GoogleFonts.firaCode(
                            fontSize: 13,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],

                    if (question.isMatchPairs) ...[
                      MatchPairsWidget(
                        key: ValueKey(question.id),
                        question: question,
                        currentMatches: qState.matchAnswers[question.id] ?? [],
                        onMatchesChanged: (matches) {
                          ref.read(quizTakeProvider.notifier).setMatchAnswer(question.id, matches);
                        },
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      // Options
                      ...question.options.asMap().entries.map((e) {
                        final idx = e.key;
                        final optText = e.value;
                        final letter = ['A', 'B', 'C', 'D'][idx % 4];
                        final selected = qState.selectedAnswers[question.id] == idx;

                        return GestureDetector(
                          onTap: () => ref.read(quizTakeProvider.notifier).selectAnswer(question.id, idx),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? (isDark ? AppColors.secondary : AppColors.primary).withOpacity(0.15)
                                  : surfaceColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? (isDark ? AppColors.secondary : AppColors.primary) : borderColor,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: selected ? (isDark ? AppColors.secondary : AppColors.primary) : surface2Color,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      letter,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: selected
                                            ? (isDark ? AppColors.onSecondaryContainer : Colors.white)
                                            : textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    optText,
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      color: onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],

                    // Mark for review
                    TextButton.icon(
                      onPressed: () => ref.read(quizTakeProvider.notifier).toggleReview(question.id),
                      icon: Icon(
                        qState.markedForReview.contains(question.id)
                            ? Icons.flag
                            : Icons.flag_outlined,
                        color: qState.markedForReview.contains(question.id)
                            ? AppColors.warning
                            : textMuted,
                        size: 18,
                      ),
                      label: Text(
                        qState.markedForReview.contains(question.id)
                            ? 'Marked for Review'
                            : 'Mark for Review',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: qState.markedForReview.contains(question.id)
                              ? AppColors.warning
                              : textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: qState.currentIndex > 0
                          ? () => ref.read(quizTakeProvider.notifier).prev()
                          : null,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderColor),
                        foregroundColor: textSecondary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('← Prev'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _openNavigator,
                    icon: Icon(Icons.grid_view_rounded, color: onSurface),
                    style: IconButton.styleFrom(
                      backgroundColor: surface2Color,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: isLast
                        ? GradientButton(
                            text: 'Submit',
                            height: 44,
                            isLoading: qState.isSubmitting,
                            onPressed: qState.isSubmitting ? null : () => _submit(),
                          )
                        : ElevatedButton(
                            onPressed: () => ref.read(quizTakeProvider.notifier).next(total),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.secondary : AppColors.primary,
                              foregroundColor: isDark ? AppColors.onSecondaryContainer : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Next →',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.onSecondaryContainer : Colors.white,
                              ),
                            ),
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

class _QuestionNavigatorSheet extends ConsumerWidget {
  final QuizModel quiz;
  final void Function(int) onSelect;
  final VoidCallback onSubmit;

  const _QuestionNavigatorSheet({
    required this.quiz,
    required this.onSelect,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qState = ref.watch(quizTakeProvider);
    final screenHeight = MediaQuery.of(context).size.height;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final surface2Color = isDark ? AppColors.pitchBlackSurface2 : AppColors.lightSurface2;
    final textSecondary = isDark ? AppColors.pitchBlackTextSecondary : AppColors.lightTextSecondary;
    final textMuted = isDark ? AppColors.pitchBlackTextMuted : AppColors.lightTextMuted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Fixed header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 8, 0),
          child: Row(
            children: [
              Text(
                'Question Navigator',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, color: onSurface),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: textSecondary, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── Scrollable question grid + legend ──
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: screenHeight * 0.45),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: quiz.questions.asMap().entries.map((e) {
                    final i = e.key;
                    final q = e.value;
                    final isCurrent = qState.currentIndex == i;
                    final isAnswered = q.isMatchPairs
                        ? ((qState.matchAnswers[q.id]?.any((p) => (p['right'] ?? '').isNotEmpty)) ?? false)
                        : qState.selectedAnswers.containsKey(q.id);
                    final isMarked = qState.markedForReview.contains(q.id);

                    Color bgColor = surface2Color;
                    Color numColor = onSurface;
                    if (isCurrent) {
                      bgColor = isDark ? AppColors.secondary : AppColors.primary;
                      numColor = isDark ? AppColors.onSecondaryContainer : Colors.white;
                    } else if (isMarked) {
                      bgColor = AppColors.warning;
                      numColor = Colors.white;
                    } else if (isAnswered) {
                      bgColor = AppColors.success;
                      numColor = Colors.white;
                    }

                    return GestureDetector(
                      onTap: () => onSelect(i),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: numColor,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                // Legend
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Legend(color: surface2Color, label: 'Not answered', textMuted: textMuted),
                    const SizedBox(width: 12),
                    _Legend(color: AppColors.success, label: 'Answered', textMuted: textMuted),
                    const SizedBox(width: 12),
                    _Legend(color: AppColors.warning, label: 'Review', textMuted: textMuted),
                  ],
                ),
              ],
            ),
          ),
        ),

        // ── Fixed Submit button ──
        Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
          child: GradientButton(text: 'Submit Quiz', height: 48, onPressed: onSubmit),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final Color textMuted;
  const _Legend({required this.color, required this.label, required this.textMuted});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: textMuted)),
      ],
    );
  }
}
