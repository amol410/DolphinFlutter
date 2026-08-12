import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/videos_repository.dart';
import '../data/models/video_model.dart';

final videosRepositoryProvider =
    Provider<VideosRepository>((ref) => VideosRepository());

class VideosListState {
  final List<VideoModel> videos;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final bool hasMore;

  const VideosListState({
    this.videos = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
  });

  VideosListState copyWith({
    List<VideoModel>? videos,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    bool? hasMore,
  }) {
    return VideosListState(
      videos: videos ?? this.videos,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class VideosListNotifier extends StateNotifier<VideosListState> {
  final VideosRepository _repo;
  String _query = '';

  VideosListNotifier(this._repo) : super(const VideosListState()) {
    fetch();
  }

  Future<void> fetch({bool refresh = false}) async {
    if (refresh) {
      state = state.copyWith(isLoading: true, page: 1, hasMore: true, videos: []);
    } else {
      state = state.copyWith(isLoading: true);
    }
    try {
      final result = await _repo.getVideos(q: _query, page: 1);
      state = state.copyWith(
        videos: result, isLoading: false, page: 1, hasMore: result.length == 12,
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
      final result = await _repo.getVideos(q: _query, page: next);
      state = state.copyWith(
        videos: [...state.videos, ...result],
        isLoadingMore: false,
        page: next,
        hasMore: result.length == 12,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void search(String q) {
    _query = q;
    fetch(refresh: true);
  }
}

final videosListProvider =
    StateNotifierProvider<VideosListNotifier, VideosListState>(
  (ref) => VideosListNotifier(ref.watch(videosRepositoryProvider)),
);

final videoDetailProvider =
    FutureProvider.family<VideoModel, String>((ref, id) async {
  return ref.watch(videosRepositoryProvider).getVideoById(id);
});
