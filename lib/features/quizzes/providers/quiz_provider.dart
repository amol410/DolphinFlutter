import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/quiz_repository.dart';
import '../data/models/quiz_model.dart';

final quizRepositoryProvider =
    Provider<QuizRepository>((ref) => QuizRepository());

// --- Quiz List ---
class QuizzesListState {
  final List<QuizModel> quizzes;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final bool hasMore;

  const QuizzesListState({
    this.quizzes = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
  });

  QuizzesListState copyWith({
    List<QuizModel>? quizzes,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    bool? hasMore,
  }) {
    return QuizzesListState(
      quizzes: quizzes ?? this.quizzes,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class QuizzesListNotifier extends StateNotifier<QuizzesListState> {
  final QuizRepository _repo;
  String _query = '';
  String _subject = '';
  String _topic = '';

  QuizzesListNotifier(this._repo) : super(const QuizzesListState()) {
    fetch();
  }

  Future<void> fetch({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, page: 1, hasMore: true, quizzes: []);
    } else {
      state = state.copyWith(isLoading: true);
    }
    try {
      final result = await _repo.getQuizzes(
        q: _query, subject: _subject, topic: _topic, page: 1,
      );
      state = state.copyWith(
        quizzes: result, isLoading: false, page: 1, hasMore: result.length == 12,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final next = state.page + 1;
      final result = await _repo.getQuizzes(
        q: _query, subject: _subject, topic: _topic, page: next,
      );
      state = state.copyWith(
        quizzes: [...state.quizzes, ...result],
        isLoadingMore: false,
        page: next,
        hasMore: result.length == 12,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void search(String q) { _query = q; fetch(refresh: true); }
  void filterSubject(String s) { _subject = s; _topic = ''; fetch(refresh: true); }
  void filterTopic(String t) { _topic = t; fetch(refresh: true); }
}

final quizzesListProvider =
    StateNotifierProvider<QuizzesListNotifier, QuizzesListState>(
  (ref) => QuizzesListNotifier(ref.watch(quizRepositoryProvider)),
);

final quizDetailProvider =
    FutureProvider.family<QuizModel, String>((ref, id) async {
  return ref.watch(quizRepositoryProvider).getQuizById(id);
});

final myAttemptsProvider =
    FutureProvider.family<List<AttemptModel>, String>((ref, quizId) async {
  return ref.watch(quizRepositoryProvider).getMyAttempts(quizId);
});

// --- Quiz Take Session ---
class QuizTakeState {
  final int currentIndex;
  final Map<int, int> selectedAnswers; // questionId → selectedIndex
  final Set<int> markedForReview;
  final int secondsRemaining;
  final bool isSubmitting;

  const QuizTakeState({
    this.currentIndex = 0,
    this.selectedAnswers = const {},
    this.markedForReview = const {},
    this.secondsRemaining = 0,
    this.isSubmitting = false,
  });

  QuizTakeState copyWith({
    int? currentIndex,
    Map<int, int>? selectedAnswers,
    Set<int>? markedForReview,
    int? secondsRemaining,
    bool? isSubmitting,
  }) {
    return QuizTakeState(
      currentIndex: currentIndex ?? this.currentIndex,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      markedForReview: markedForReview ?? this.markedForReview,
      secondsRemaining: secondsRemaining ?? this.secondsRemaining,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class QuizTakeNotifier extends StateNotifier<QuizTakeState> {
  QuizTakeNotifier() : super(const QuizTakeState());

  void init(int timeLimitMinutes) {
    state = QuizTakeState(
      secondsRemaining: timeLimitMinutes > 0 ? timeLimitMinutes * 60 : 0,
    );
  }

  void selectAnswer(int questionId, int selectedIndex) {
    final updated = Map<int, int>.from(state.selectedAnswers);
    updated[questionId] = selectedIndex;
    state = state.copyWith(selectedAnswers: updated);
  }

  void toggleReview(int questionId) {
    final updated = Set<int>.from(state.markedForReview);
    if (updated.contains(questionId)) {
      updated.remove(questionId);
    } else {
      updated.add(questionId);
    }
    state = state.copyWith(markedForReview: updated);
  }

  void goTo(int index) => state = state.copyWith(currentIndex: index);
  void next(int total) {
    if (state.currentIndex < total - 1) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }
  void prev() {
    if (state.currentIndex > 0) {
      state = state.copyWith(currentIndex: state.currentIndex - 1);
    }
  }

  void tick() {
    if (state.secondsRemaining > 0) {
      state = state.copyWith(secondsRemaining: state.secondsRemaining - 1);
    }
  }

  void setSubmitting(bool v) => state = state.copyWith(isSubmitting: v);

  int get unansweredCount => 0; // computed externally with question list length
}

final quizTakeProvider =
    StateNotifierProvider.autoDispose<QuizTakeNotifier, QuizTakeState>(
  (ref) => QuizTakeNotifier(),
);
