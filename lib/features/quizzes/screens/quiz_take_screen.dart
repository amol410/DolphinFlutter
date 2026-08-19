import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../providers/quiz_provider.dart';
import '../data/models/quiz_model.dart';

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
    // Prevent double-submission
    if (ref.read(quizTakeProvider).isSubmitting) return;

    final qState = ref.read(quizTakeProvider);
    final unanswered = quiz.questions.length - qState.selectedAnswers.length;

    if (!autoSubmit && unanswered > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        // Use dialogContext (the dialog's own BuildContext) for Navigator.pop.
        // Using the screen's `context` inside a ShellRoute pops the ROUTE,
        // not the dialog — which is why the detail screen appeared with the
        // dialog still overlaid. dialogContext is scoped to the overlay entry.
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Submit Quiz?',
            style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.w600)),
          content: Text(
            'You have $unanswered unanswered question${unanswered > 1 ? 's' : ''}. Submit anyway?',
            style: GoogleFonts.inter(color: AppColors.textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Submit', style: GoogleFonts.inter(color: AppColors.error))),
          ],
        ),
      );
      if (confirm != true) return;
    }

    // Stop the timer immediately to prevent double-submit from auto-fire
    _timer?.cancel();
    _timer = null;

    ref.read(quizTakeProvider.notifier).setSubmitting(true);
    try {
      final answers = qState.selectedAnswers.entries
          .map((e) => {'questionId': e.key, 'chosenIndex': e.value})
          .toList();
      final timeTaken = ((DateTime.now().millisecondsSinceEpoch - _startTime) / 1000).round();
      final result = await ref.read(quizRepositoryProvider).submitAttempt(
        widget.quizId, answers, timeTaken,
      );
      if (!mounted) return;

      // Build the result data map
      final resultData = <String, dynamic>{
        'score': result.score,
        'maxScore': result.maxScore,
        'percentage': result.percentage,
        'passed': result.passed,
        'answers': result.answers,
        'timeTaken': timeTaken,
        'questions': quiz.questions,
      };

      // Store result in provider BEFORE navigating so the result screen
      // can always read it even if go_router drops the extra object.
      ref.read(quizResultProvider(widget.quizId).notifier).state = resultData;

      // Use pushReplacement so go_router keeps the ShellRoute alive and
      // correctly passes the extra Map to the result route builder.
      context.pushReplacement(
        '/quizzes/${widget.quizId}/result',
        extra: resultData,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: ${e.toString()}'),
            backgroundColor: AppColors.error),
      );
      ref.read(quizTakeProvider.notifier).setSubmitting(false);
    }
  }

  void _openNavigator() {
    final quiz = _quiz;
    if (quiz == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => _QuestionNavigatorSheet(
        quiz: quiz,
        onSelect: (i) {
          Navigator.pop(sheetContext);
          ref.read(quizTakeProvider.notifier).goTo(i);
        },
        onSubmit: () {
          // Dismiss the bottom sheet first, then submit.
          // Using sheetContext ensures we pop the correct route.
          Navigator.pop(sheetContext);
          // Small delay to let the bottom sheet dismiss animation complete
          // before showing the submit confirmation dialog.
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

    if (quiz == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
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
      backgroundColor: AppColors.background,
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
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(quiz.title,
                      style: GoogleFonts.inter(fontSize: 14, color: Colors.white),
                      overflow: TextOverflow.ellipsis),
                  ),
                  if (quiz.timeLimit > 0)
                    CircularPercentIndicator(
                      radius: 28,
                      lineWidth: 3,
                      percent: secondsRemaining / (quiz.timeLimit * 60),
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
                    color: AppColors.primary,
                    backgroundColor: AppColors.surface2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                  Text('Q${qState.currentIndex + 1} of $total',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted)),
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
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('Q${qState.currentIndex + 1}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              )),
                          ),
                          const SizedBox(height: 12),
                          Text(question.text,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Options
                    ...question.options.asMap().entries.map((e) {
                      final idx = e.key;
                      final optText = e.value;
                      final letter = ['A', 'B', 'C', 'D'][idx];
                      final selected = qState.selectedAnswers[question.id] == idx;

                      return GestureDetector(
                        onTap: () => ref.read(quizTakeProvider.notifier)
                            .selectAnswer(question.id, idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.primary.withOpacity(0.12)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? AppColors.primary : AppColors.border,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 30, height: 30,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.surface2,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(letter,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    )),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(optText,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: Colors.white,
                                  )),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    // Mark for review
                    TextButton.icon(
                      onPressed: () => ref.read(quizTakeProvider.notifier)
                          .toggleReview(question.id),
                      icon: Icon(
                        qState.markedForReview.contains(question.id)
                            ? Icons.flag
                            : Icons.flag_outlined,
                        color: qState.markedForReview.contains(question.id)
                            ? AppColors.warning
                            : AppColors.textMuted,
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
                              : AppColors.textMuted,
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
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.surface2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: qState.currentIndex > 0
                          ? () => ref.read(quizTakeProvider.notifier).prev()
                          : null,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.textMuted),
                        foregroundColor: AppColors.textSecondary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('← Prev'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _openNavigator,
                    icon: const Icon(Icons.grid_view_rounded, color: AppColors.textSecondary),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
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
                            onPressed: () =>
                                ref.read(quizTakeProvider.notifier).next(total),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Next →'),
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

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text('Question Navigator',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: AppColors.textSecondary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: quiz.questions.asMap().entries.map((e) {
              final i = e.key;
              final q = e.value;
              final isCurrent = qState.currentIndex == i;
              final isAnswered = qState.selectedAnswers.containsKey(q.id);
              final isMarked = qState.markedForReview.contains(q.id);

              Color bgColor = AppColors.surface2;
              if (isCurrent) bgColor = AppColors.primary;
              else if (isMarked) bgColor = AppColors.warning;
              else if (isAnswered) bgColor = AppColors.success;

              return GestureDetector(
                onTap: () => onSelect(i),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      )),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: AppColors.surface2, label: 'Not answered'),
              const SizedBox(width: 12),
              _Legend(color: AppColors.success, label: 'Answered'),
              const SizedBox(width: 12),
              _Legend(color: AppColors.warning, label: 'Review'),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(text: 'Submit Quiz', height: 48, onPressed: onSubmit),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 4),
        Text(label,
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
      ],
    );
  }
}
