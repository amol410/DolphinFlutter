import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/notes_repository.dart';
import '../data/models/note_model.dart';

final notesRepositoryProvider =
    Provider<NotesRepository>((ref) => NotesRepository());

// --- List State ---
class NotesListState {
  final List<NoteModel> notes;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final bool hasMore;

  const NotesListState({
    this.notes = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
  });

  NotesListState copyWith({
    List<NoteModel>? notes,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    bool? hasMore,
  }) {
    return NotesListState(
      notes: notes ?? this.notes,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class NotesListNotifier extends StateNotifier<NotesListState> {
  final NotesRepository _repo;
  String _query = '';
  String _subject = '';
  String _topic = '';

  NotesListNotifier(this._repo) : super(const NotesListState()) {
    fetch();
  }

  Future<void> fetch({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, page: 1, hasMore: true, notes: []);
    } else {
      state = state.copyWith(isLoading: true);
    }
    try {
      final result = await _repo.getNotes(
        q: _query,
        subject: _subject,
        topic: _topic,
        page: 1,
        limit: 6,
      );
      state = state.copyWith(
        notes: result,
        isLoading: false,
        page: 1,
        hasMore: result.length == 6,
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
      final result = await _repo.getNotes(
        q: _query,
        subject: _subject,
        topic: _topic,
        page: next,
        limit: 6,
      );
      state = state.copyWith(
        notes: [...state.notes, ...result],
        isLoadingMore: false,
        page: next,
        hasMore: result.length == 6,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void search(String q) {
    _query = q;
    fetch(refresh: true);
  }

  void filterSubject(String subject) {
    _subject = subject;
    _topic = '';
    fetch(refresh: true);
  }

  void filterTopic(String topic) {
    _topic = topic;
    fetch(refresh: true);
  }
}

final notesListProvider =
    StateNotifierProvider<NotesListNotifier, NotesListState>(
  (ref) => NotesListNotifier(ref.watch(notesRepositoryProvider)),
);

final noteDetailProvider =
    FutureProvider.family<NoteModel, String>((ref, id) async {
  return ref.watch(notesRepositoryProvider).getNoteById(id);
});
