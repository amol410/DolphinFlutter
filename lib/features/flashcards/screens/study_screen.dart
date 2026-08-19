import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/gradient_button.dart';
import '../../../shared/widgets/shimmer_loader.dart';
import '../providers/flashcard_provider.dart';
import '../data/models/flashcard_model.dart';

class StudyScreen extends ConsumerStatefulWidget {
  final String deckId;
  const StudyScreen({super.key, required this.deckId});

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  FlashcardDeck? _deck;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDeck();
  }

  Future<void> _loadDeck() async {
    try {
      final deck = await ref.read(flashcardRepositoryProvider).getDeckById(widget.deckId);
      setState(() { _deck = deck; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _saveAndPop() async {
    final session = ref.read(studySessionProvider);
    await ref.read(flashcardRepositoryProvider).saveProgress(
      widget.deckId,
      session.cardResults,
      session.cardResults.values.where((v) => v == 'known').length,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const ShimmerListLoader(count: 3),
      );
    }
    final deck = _deck;
    if (deck == null || deck.cards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(
          child: Text('No cards in this deck', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final session = ref.watch(studySessionProvider);
    final cards = deck.cards;
    final total = cards.length;

    if (session.isComplete) {
      final mastered = session.masteredCount();
      final pct = total > 0 ? mastered / total : 0.0;
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🎉', style: const TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text('Complete!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 24),
                  CircularPercentIndicator(
                    radius: 60,
                    lineWidth: 10,
                    percent: pct.clamp(0.0, 1.0),
                    progressColor: AppColors.success,
                    backgroundColor: AppColors.success.withOpacity(0.15),
                    animation: true,
                    center: Text('${(pct * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      )),
                  ),
                  const SizedBox(height: 16),
                  Text('$mastered / $total cards mastered',
                    style: GoogleFonts.inter(fontSize: 15, color: AppColors.textSecondary)),
                  const SizedBox(height: 32),
                  GradientButton(
                    text: 'Study Again',
                    onPressed: () => ref.read(studySessionProvider.notifier).restart(),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: _saveAndPop,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.textMuted),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Back to Decks'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final card = cards[session.currentIndex];
    final progress = (session.currentIndex + 1) / total;

    return WillPopScope(
      onWillPop: () async { await _saveAndPop(); return false; },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _saveAndPop,
                          child: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.close,
                                color: Colors.white, size: 18),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(deck.deckName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis),
                        ),
                        Text(
                          '${session.currentIndex + 1} / $total',
                          style: GoogleFonts.inter(
                            fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface2,
                      minHeight: 3,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                ),
              ),

              // Flip card area
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: GestureDetector(
                      onTap: () => ref.read(studySessionProvider.notifier).flip(),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(scale: animation, child: child);
                        },
                        child: session.isFlipped
                            ? _BackCard(key: const ValueKey('back'), card: card,
                                showHint: session.showHint)
                            : _FrontCard(key: const ValueKey('front'), card: card),
                      ),
                    ),
                  ),
                ),
              ),

              // Hint button
              if (!session.isFlipped && card.hint != null && card.hint!.isNotEmpty)
                TextButton.icon(
                  onPressed: () => ref.read(studySessionProvider.notifier).showHint(),
                  icon: const Icon(Icons.lightbulb_outline,
                      color: AppColors.warning, size: 18),
                  label: Text('Show Hint',
                    style: GoogleFonts.inter(color: AppColors.warning, fontSize: 13)),
                ),

              // Bottom controls
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  children: [
                    // Nav row
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: session.currentIndex > 0
                                ? () => ref.read(studySessionProvider.notifier).prev()
                                : null,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.textMuted),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('← Prev'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => ref.read(studySessionProvider.notifier)
                                .next(total),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(session.currentIndex == total - 1
                                ? 'Finish' : 'Next →'),
                          ),
                        ),
                      ],
                    ),
                    // Rating row (only when flipped)
                    if (session.isFlipped) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => ref.read(studySessionProvider.notifier)
                                  .rate(card.id, 'unknown', total),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.error),
                                foregroundColor: AppColors.error,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text('✗  Still Learning',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => ref.read(studySessionProvider.notifier)
                                  .rate(card.id, 'known', total),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text('✓  Got It!',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
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
        ),
      ),
    );
  }
}

class _FrontCard extends StatelessWidget {
  final Flashcard card;
  const _FrontCard({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.06),
            blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 12, right: 14,
            child: Text('Tap to flip 👆',
              style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(card.front,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
                maxLines: 6,
                overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackCard extends StatelessWidget {
  final Flashcard card;
  final bool showHint;
  const _BackCard({super.key, required this.card, required this.showHint});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.15),
            AppColors.accent.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.topLeft,
              child: Text('ANSWER',
                style: GoogleFonts.inter(
                  fontSize: 10, color: AppColors.textMuted,
                  fontWeight: FontWeight.w600, letterSpacing: 1.2)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(card.back,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis),
          ),
          if (showHint && card.hint != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('💡 ${card.hint}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFFD1D5DB),
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            ),
          ],
        ],
      ),
    );
  }
}
