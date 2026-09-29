import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/flashcard_repository.dart';
import '../data/models/flashcard_model.dart';
import 'flashcard_provider.dart';

class DifficultWordsState {
  final Set<String> bookmarkedFronts; // lowercase trimmed fronts
  final int activeVolume;
  final int currentCardCount; // 0..10
  final String? activeDeckId;
  final bool isLoading;

  const DifficultWordsState({
    this.bookmarkedFronts = const {},
    this.activeVolume = 1,
    this.currentCardCount = 0,
    this.activeDeckId,
    this.isLoading = false,
  });

  DifficultWordsState copyWith({
    Set<String>? bookmarkedFronts,
    int? activeVolume,
    int? currentCardCount,
    String? activeDeckId,
    bool? isLoading,
  }) {
    return DifficultWordsState(
      bookmarkedFronts: bookmarkedFronts ?? this.bookmarkedFronts,
      activeVolume: activeVolume ?? this.activeVolume,
      currentCardCount: currentCardCount ?? this.currentCardCount,
      activeDeckId: activeDeckId ?? this.activeDeckId,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  bool isBookmarked(String front) {
    return bookmarkedFronts.contains(front.trim().toLowerCase());
  }
}

class DifficultWordsNotifier extends StateNotifier<DifficultWordsState> {
  final FlashcardRepository _repository;
  final Ref _ref;

  DifficultWordsNotifier(this._repository, this._ref) : super(const DifficultWordsState()) {
    loadState();
  }

  Future<void> loadState() async {
    try {
      state = state.copyWith(isLoading: true);
      final decks = await _repository.getDecks();

      final difficultDecks = decks.where((d) => d.deckName.startsWith('Difficult Words')).toList();

      final Set<String> fronts = {};
      int maxVol = 0;
      FlashcardDeck? latestDeck;

      final regex = RegExp(r'Difficult Words - Vol (\d+)');

      for (final deck in difficultDecks) {
        for (final card in deck.cards) {
          if (card.front.trim().isNotEmpty) {
            fronts.add(card.front.trim().toLowerCase());
          }
        }

        final match = regex.firstMatch(deck.deckName);
        if (match != null) {
          final vol = int.tryParse(match.group(1) ?? '1') ?? 1;
          if (vol > maxVol) {
            maxVol = vol;
            latestDeck = deck;
          }
        }
      }

      if (maxVol == 0) {
        // No difficult words deck yet
        state = DifficultWordsState(
          bookmarkedFronts: fronts,
          activeVolume: 1,
          currentCardCount: 0,
          activeDeckId: null,
          isLoading: false,
        );
      } else if (latestDeck != null && latestDeck.cards.length < 10) {
        // Existing deck still has room (1..9 cards)
        state = DifficultWordsState(
          bookmarkedFronts: fronts,
          activeVolume: maxVol,
          currentCardCount: latestDeck.cards.length,
          activeDeckId: latestDeck.id,
          isLoading: false,
        );
      } else {
        // Latest deck is full (>= 10 cards), next will be maxVol + 1
        state = DifficultWordsState(
          bookmarkedFronts: fronts,
          activeVolume: maxVol + 1,
          currentCardCount: 0,
          activeDeckId: null,
          isLoading: false,
        );
      }
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Toggles bookmark for a word/question.
  /// Returns a user-friendly feedback message (e.g., "Added to Difficult Words - Vol 1 (4/10)").
  Future<String> toggleBookmark({
    required String front,
    required String back,
    String? hint,
  }) async {
    final cleanFront = front.trim();
    final cleanKey = cleanFront.toLowerCase();

    if (state.isBookmarked(cleanKey)) {
      // ─── REMOVE / UNDO ───
      final updatedFronts = Set<String>.from(state.bookmarkedFronts)..remove(cleanKey);
      state = state.copyWith(bookmarkedFronts: updatedFronts);

      try {
        final decks = await _repository.getDecks();
        for (final deck in decks.where((d) => d.deckName.startsWith('Difficult Words'))) {
          final cardIndex = deck.cards.indexWhere((c) => c.front.trim().toLowerCase() == cleanKey);
          if (cardIndex != -1) {
            final updatedCards = List<Flashcard>.from(deck.cards)..removeAt(cardIndex);
            final cardsPayload = updatedCards
                .map((c) => {'front': c.front, 'back': c.back, 'hint': c.hint ?? ''})
                .toList();
            await _repository.updateDeckCards(deck.id, cardsPayload);
            _ref.invalidate(flashcardListProvider);
            break;
          }
        }
        await loadState();
      } catch (_) {
        // Revert on error if necessary
      }
      return 'Removed from Difficult Words';
    } else {
      // ─── ADD BOOKMARK ───
      // Optimistic update
      final updatedFronts = Set<String>.from(state.bookmarkedFronts)..add(cleanKey);
      state = state.copyWith(bookmarkedFronts: updatedFronts);

      try {
        final newCard = {
          'front': cleanFront,
          'back': back.trim(),
          'hint': hint?.trim() ?? '',
        };

        if (state.activeDeckId != null && state.currentCardCount < 10) {
          // Append to active deck
          final decks = await _repository.getDecks();
          final activeDeck = decks.firstWhere(
            (d) => d.id == state.activeDeckId,
            orElse: () => FlashcardDeck(id: state.activeDeckId!, deckName: ''),
          );

          final existingPayload = activeDeck.cards
              .map((c) => {'front': c.front, 'back': c.back, 'hint': c.hint ?? ''})
              .toList();
          existingPayload.add(newCard);

          await _repository.updateDeckCards(state.activeDeckId!, existingPayload);
          _ref.invalidate(flashcardListProvider);

          final newCount = existingPayload.length;
          await loadState();

          if (newCount >= 10) {
            return 'Added to Difficult Words - Vol ${state.activeVolume - 1} (10/10) • Deck Complete! 🎉';
          }
          return 'Added to Difficult Words - Vol ${state.activeVolume} ($newCount/10)';
        } else {
          // Create new deck with 10-cap logic
          final newVol = state.activeVolume;
          await _repository.createDeck(
            deckName: 'Difficult Words - Vol $newVol',
            description: 'Curated difficult words from quiz results (10 words max)',
            cards: [newCard],
            color: 'purple',
            tags: ['difficult-words'],
            isPublic: false,
          );
          _ref.invalidate(flashcardListProvider);
          await loadState();
          return 'Added to Difficult Words - Vol $newVol (1/10)';
        }
      } catch (e) {
        // Revert optimistic add
        final revertedFronts = Set<String>.from(state.bookmarkedFronts)..remove(cleanKey);
        state = state.copyWith(bookmarkedFronts: revertedFronts);
        return 'Could not save to flashcards: ${e.toString()}';
      }
    }
  }
}

final difficultWordsProvider =
    StateNotifierProvider<DifficultWordsNotifier, DifficultWordsState>((ref) {
  final repo = ref.watch(flashcardRepositoryProvider);
  return DifficultWordsNotifier(repo, ref);
});
