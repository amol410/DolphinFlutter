import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/sound_effects_service.dart';
import '../../../core/services/tts_service.dart';
import '../../../shared/widgets/animated_dolphin_mascot.dart';
import '../../../shared/widgets/duo_feedback_sheet.dart';
import '../../../shared/widgets/tactile_game_button.dart';
import '../providers/gamification_provider.dart';

class PlacementQuizScreen extends ConsumerStatefulWidget {
  final String targetLanguage;
  final String nativeLanguage;
  final int? jumpToUnit;
  final String? jumpUnitTitle;

  const PlacementQuizScreen({
    super.key,
    required this.targetLanguage,
    required this.nativeLanguage,
    this.jumpToUnit,
    this.jumpUnitTitle,
  });

  bool get isJumpMode => jumpToUnit != null && jumpToUnit! >= 2;

  @override
  ConsumerState<PlacementQuizScreen> createState() => _PlacementQuizScreenState();
}

class _PlacementQuizScreenState extends ConsumerState<PlacementQuizScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<Map<String, dynamic>> _questions = [];
  int _currentIndex = 0;
  int _correctCount = 0;
  int _mistakesCount = 0;

  // Current question state
  String? _selectedOption;
  final List<int> _selectedTokenIndices = [];
  bool? _isCurrentCorrect;
  String _expectedAnswer = '';

  // Final result state
  Map<String, dynamic>? _evaluationResult;
  bool _failedJumpHeartLimit = false;

  @override
  void initState() {
    super.initState();
    TtsService().setLanguage(widget.targetLanguage);
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    final repo = ref.read(gamificationRepositoryProvider);
    final fetched = await repo.getPlacementQuestions(
      targetLanguage: widget.targetLanguage,
      nativeLanguage: widget.nativeLanguage,
      mode: widget.isJumpMode ? 'jump' : 'placement',
      targetUnitNumber: widget.jumpToUnit,
    );

    if (!mounted) return;
    setState(() {
      _questions = fetched;
      _isLoading = false;
    });
    _speakIfAudioQuestion(0);
  }

  void _speakIfAudioQuestion(int index) {
    if (index < 0 || index >= _questions.length) return;
    final q = _questions[index];
    final type = q['type']?.toString() ?? '';
    if (type == 'listen_select' || type == 'dialogue_bubble') {
      final sentence = (q['sentence'] ?? q['partnerMessage'] ?? '').toString().trim();
      if (sentence.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _currentIndex == index) {
            TtsService().speakSentence(sentence);
          }
        });
      }
    }
  }

  void _checkAnswer() {
    if (_currentIndex >= _questions.length || _isCurrentCorrect != null) return;
    final q = _questions[_currentIndex];
    final type = q['type']?.toString() ?? 'cloze_test';
    final expected = (q['correctAnswer'] ?? q['targetSentence'] ?? '').toString().trim();

    bool isCorrect = false;
    if (type == 'sentence_builder') {
      final tokens = (q['tokens'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final built = _selectedTokenIndices.map((i) => tokens[i]).join(' ').trim();
      final cleanBuilt = built.toLowerCase().replaceAll(RegExp(r'[.,!?]'), '');
      final cleanExp = expected.toLowerCase().replaceAll(RegExp(r'[.,!?]'), '');
      isCorrect = cleanBuilt == cleanExp;
    } else {
      isCorrect = (_selectedOption ?? '').trim().toLowerCase() == expected.toLowerCase();
    }

    if (isCorrect) {
      SoundEffectsService.instance.playCorrect();
      _correctCount++;
    } else {
      SoundEffectsService.instance.playWrong();
      _mistakesCount++;
    }

    setState(() {
      _isCurrentCorrect = isCorrect;
      _expectedAnswer = expected;
    });
  }

  Future<void> _nextQuestion() async {
    // In Jump Mode, > 3 mistakes fails the jump test early (Duolingo 3-heart rule)
    if (widget.isJumpMode && _mistakesCount > 3) {
      setState(() {
        _failedJumpHeartLimit = true;
      });
      return;
    }

    if (_currentIndex + 1 < _questions.length) {
      final nextIdx = _currentIndex + 1;
      setState(() {
        _currentIndex = nextIdx;
        _selectedOption = null;
        _selectedTokenIndices.clear();
        _isCurrentCorrect = null;
        _expectedAnswer = '';
      });
      _speakIfAudioQuestion(nextIdx);
    } else {
      await _submitFinalEvaluation();
    }
  }

  Future<void> _submitFinalEvaluation() async {
    setState(() => _isSubmitting = true);
    final total = _questions.isNotEmpty ? _questions.length : 12;
    final scorePct = ((_correctCount / total) * 100).round().clamp(0, 100);
    final repo = ref.read(gamificationRepositoryProvider);

    if (widget.isJumpMode) {
      final res = await repo.jumpSection(
        targetUnitNumber: widget.jumpToUnit!,
        scorePct: scorePct,
        mistakesCount: _mistakesCount,
        targetLanguage: widget.targetLanguage,
        nativeLanguage: widget.nativeLanguage,
      );
      if (!mounted) return;
      await ref.read(gamificationStatusProvider.notifier).refresh();
      await ref.read(pathNodesProvider.notifier).loadPath(
            targetLanguage: widget.targetLanguage,
            nativeLanguage: widget.nativeLanguage,
            startUnit: 1,
            endUnit: (widget.jumpToUnit! + 3).clamp(4, 105),
          );
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _evaluationResult = res;
      });
    } else {
      final res = await repo.evaluatePlacement(
        scorePct: scorePct,
        correctCount: _correctCount,
        totalQuestions: total,
        targetLanguage: widget.targetLanguage,
        nativeLanguage: widget.nativeLanguage,
      );
      if (!mounted) return;
      await ref.read(gamificationStatusProvider.notifier).refresh();
      final placement = res['placement'] as Map<String, dynamic>?;
      final targetUnit = (placement?['targetUnitNumber'] as num?)?.toInt() ?? 1;
      final effectiveLevel = placement?['effectiveLevel']?.toString() ?? 'A1';
      await ref.read(pathNodesProvider.notifier).loadPath(
            targetLanguage: widget.targetLanguage,
            nativeLanguage: widget.nativeLanguage,
            level: effectiveLevel,
            startUnit: 1,
            endUnit: targetUnit > 4 ? targetUnit + 4 : 6,
          );
      if (!mounted) return;
      SoundEffectsService.instance.playFanfare();
      setState(() {
        _isSubmitting = false;
        _evaluationResult = res;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isSubmitting) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF0284C7)),
              const SizedBox(height: 18),
              Text(
                _isSubmitting
                    ? 'Calculating your CEFR proficiency...'
                    : 'Preparing Diagnostic Placement Test...',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_failedJumpHeartLimit) {
      return _buildJumpFailedView();
    }

    if (_evaluationResult != null) {
      return _buildEvaluationResultView();
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: TactileGameButton(
            text: 'CONTINUE TO MAP',
            onPressed: () => context.go('/home'),
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];
    final type = q['type']?.toString() ?? 'cloze_test';
    final cefr = q['cefr']?.toString() ?? 'A1';
    final progress = (_currentIndex + 1) / _questions.length;
    final canSubmit = type == 'sentence_builder'
        ? _selectedTokenIndices.isNotEmpty
        : (_selectedOption != null && _selectedOption!.isNotEmpty);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 26),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(false);
            } else {
              context.go('/home');
            }
          },
        ),
        title: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 12,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF0284C7)),
            ),
          ),
        ),
        actions: [
          if (widget.isJumpMode)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: List.generate(3, (idx) {
                  final alive = idx < (3 - _mistakesCount);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 20,
                      color: alive ? const Color(0xFFFF4B4B) : const Color(0xFFCBD5E1),
                    ),
                  );
                }),
              ),
            )
          else
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF38BDF8)),
              ),
              child: Text(
                cefr,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0284C7),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isJumpMode
                          ? 'Unit ${widget.jumpToUnit} Jump Challenge'
                          : 'Question ${_currentIndex + 1} of ${_questions.length}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0284C7),
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      q['prompt']?.toString() ?? 'Complete the challenge',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (type == 'sentence_builder')
                      _buildSentenceBuilderQuestion(q)
                    else
                      _buildMcqQuestion(q, type),
                  ],
                ),
              ),
            ),
            if (_isCurrentCorrect == null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: TactileGameButton(
                  text: 'CHECK ANSWER',
                  variant: GameButtonVariant.success,
                  height: 54,
                  onPressed: canSubmit ? _checkAnswer : null,
                ),
              )
            else
              DuoFeedbackSheet(
                isSuccess: _isCurrentCorrect == true,
                title: _isCurrentCorrect == true ? 'Spot on!' : 'Not quite right',
                subtitle: _isCurrentCorrect == true
                    ? 'Great job!'
                    : 'Correct answer: $_expectedAnswer',
                buttonText: 'CONTINUE →',
                onContinue: _nextQuestion,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMcqQuestion(Map<String, dynamic> q, String type) {
    final sentence = (q['sentence'] ?? q['partnerMessage'] ?? '').toString();
    final translation = (q['translation'] ?? '').toString();
    final options = (q['options'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0xFFE2E8F0), offset: Offset(0, 3), blurRadius: 0),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => TtsService().speakSentence(sentence.replaceAll('_____', '')),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFF0369A1), offset: Offset(0, 3), blurRadius: 0),
                    ],
                  ),
                  child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sentence,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    if (translation.isNotEmpty && type != 'listen_select') ...[
                      const SizedBox(height: 4),
                      Text(
                        translation,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        ...options.map((opt) {
          final isSelected = _selectedOption == opt;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GestureDetector(
              onTap: _isCurrentCorrect != null
                  ? null
                  : () {
                      SoundEffectsService.instance.playPop();
                      setState(() => _selectedOption = opt);
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE0F2FE) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected ? const Color(0xFF0369A1) : const Color(0xFFCBD5E1),
                      offset: const Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  opt,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF1E293B),
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSentenceBuilderQuestion(Map<String, dynamic> q) {
    final tokens = (q['tokens'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
          ),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedTokenIndices.map((idx) {
              final word = tokens[idx];
              return GestureDetector(
                onTap: _isCurrentCorrect != null
                    ? null
                    : () {
                        SoundEffectsService.instance.playPop();
                        setState(() => _selectedTokenIndices.remove(idx));
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
                  ),
                  child: Text(
                    word,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0369A1),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: tokens.asMap().entries.map((entry) {
            final idx = entry.key;
            final word = entry.value;
            final isUsed = _selectedTokenIndices.contains(idx);
            return GestureDetector(
              onTap: (isUsed || _isCurrentCorrect != null)
                  ? null
                  : () {
                      SoundEffectsService.instance.playPop();
                      TtsService().speakWord(word);
                      setState(() => _selectedTokenIndices.add(idx));
                    },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isUsed ? const Color(0xFFF1F5F9) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isUsed ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: isUsed
                      ? null
                      : const [
                          BoxShadow(
                            color: Color(0xFFCBD5E1),
                            offset: Offset(0, 3),
                            blurRadius: 0,
                          ),
                        ],
                ),
                child: Text(
                  word,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isUsed ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildJumpFailedView() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AnimatedDolphinMascot(size: 150, pose: MascotPose.thinking),
              const SizedBox(height: 24),
              Text(
                'Out of Hearts for this Jump!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Jumping ahead requires 80% accuracy with at most 3 mistakes. Practice a few more lessons and try again anytime!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 32),
              TactileGameButton(
                text: 'BACK TO MAP',
                variant: GameButtonVariant.primary,
                height: 54,
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop(false);
                  } else {
                    context.go('/home');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEvaluationResultView() {
    if (widget.isJumpMode) {
      final passed = _evaluationResult?['passed'] == true;
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedDolphinMascot(
                  size: 165,
                  pose: passed ? MascotPose.celebrate : MascotPose.thinking,
                ),
                const SizedBox(height: 24),
                Text(
                  passed ? 'UNIT ${widget.jumpToUnit} UNLOCKED!' : 'Almost There!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: passed ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _evaluationResult?['message']?.toString() ??
                      (passed
                          ? 'You jumped ahead to Unit ${widget.jumpToUnit}!'
                          : 'Keep practicing to unlock this unit.'),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 32),
                TactileGameButton(
                  text: 'CONTINUE TO MAP',
                  variant: GameButtonVariant.success,
                  height: 56,
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop(passed);
                    } else {
                      context.go('/home');
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    final placement = _evaluationResult?['placement'] as Map<String, dynamic>? ?? {};
    final assignedLevel = placement['assignedLevel']?.toString() ?? 'A1';
    final effectiveLevel = placement['effectiveLevel']?.toString() ?? 'A1';
    final isFallback = placement['isFallback'] == true;
    final scorePct = placement['scorePct'] ?? 0;
    final targetUnit = placement['targetUnitNumber'] ?? 1;
    final targetSectionTitle = placement['targetSectionTitle']?.toString() ?? 'Explorer';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const AnimatedDolphinMascot(size: 175, pose: MascotPose.celebrate),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
                ),
                child: Text(
                  'CEFR PROFICIENCY: $assignedLevel ($scorePct%)',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0284C7),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isFallback
                    ? 'Fast-Tracked to Section 2: $targetSectionTitle!'
                    : 'Welcome to Level $effectiveLevel!',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isFallback
                    ? 'You tested into $assignedLevel! We have unlocked Section 1 and placed you directly at A1 Section 2 ($targetSectionTitle, Unit $targetUnit) while your $assignedLevel modules are being finalized.'
                    : (assignedLevel == 'A1'
                        ? 'We will start from Unit 1 to build your rock-solid foundation step by step!'
                        : 'Your $effectiveLevel curriculum is unlocked and ready. Let\'s dive in!'),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF475569),
                  height: 1.45,
                ),
              ),
              const Spacer(),
              TactileGameButton(
                text: 'START LEARNING →',
                variant: GameButtonVariant.success,
                height: 56,
                onPressed: () => context.go('/home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
