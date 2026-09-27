import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/flashcard_repository.dart';
import '../data/models/flashcard_model.dart';

final flashcardRepositoryProvider =
    Provider<FlashcardRepository>((ref) => FlashcardRepository());

final flashcardListProvider =
    FutureProvider<List<FlashcardDeck>>((ref) async {
  return ref.watch(flashcardRepositoryProvider).getDecks();
});

final deckDetailProvider =
    FutureProvider.family<FlashcardDeck, String>((ref, id) async {
  return ref.watch(flashcardRepositoryProvider).getDeckById(id);
});

// --- Study Session ---
class StudySessionState {
  final int currentIndex;
  final bool isFlipped;
  final bool showHint;
  final Map<String, String> cardResults; // cardId → 'known' | 'unknown'
  final bool isComplete;

  const StudySessionState({
    this.currentIndex = 0,
    this.isFlipped = false,
    this.showHint = false,
    this.cardResults = const {},
    this.isComplete = false,
  });

  StudySessionState copyWith({
    int? currentIndex,
    bool? isFlipped,
    bool? showHint,
    Map<String, String>? cardResults,
    bool? isComplete,
  }) {
    return StudySessionState(
      currentIndex: currentIndex ?? this.currentIndex,
      isFlipped: isFlipped ?? this.isFlipped,
      showHint: showHint ?? this.showHint,
      cardResults: cardResults ?? this.cardResults,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  int masteredCount() => cardResults.values.where((v) => v == 'known').length;
}

class StudySessionNotifier extends StateNotifier<StudySessionState> {
  StudySessionNotifier() : super(const StudySessionState());

  void flip() => state = state.copyWith(isFlipped: !state.isFlipped);

  void showHint() => state = state.copyWith(showHint: true);

  void rate(String cardId, String result, int totalCards) {
    final updated = Map<String, String>.from(state.cardResults);
    updated[cardId] = result;
    final nextIndex = state.currentIndex + 1;
    final done = nextIndex >= totalCards;
    state = state.copyWith(
      cardResults: updated,
      currentIndex: done ? state.currentIndex : nextIndex,
      isFlipped: false,
      showHint: false,
      isComplete: done,
    );
  }

  void next(int totalCards) {
    if (state.currentIndex < totalCards - 1) {
      state = state.copyWith(
        currentIndex: state.currentIndex + 1,
        isFlipped: false,
        showHint: false,
      );
    }
  }

  void prev() {
    if (state.currentIndex > 0) {
      state = state.copyWith(
        currentIndex: state.currentIndex - 1,
        isFlipped: false,
        showHint: false,
      );
    }
  }

  void restart() {
    state = const StudySessionState();
  }

  void reset() => restart();
}

final studySessionProvider =
    StateNotifierProvider.autoDispose<StudySessionNotifier, StudySessionState>(
  (ref) => StudySessionNotifier(),
);
