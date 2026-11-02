import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolphincoder/core/constants/api_constants.dart';
import 'package:dolphincoder/core/network/dio_client.dart';
import 'package:dolphincoder/features/videos/data/models/video_model.dart';
import 'package:dolphincoder/features/videos/data/videos_repository.dart';
import 'package:dolphincoder/features/videos/providers/videos_provider.dart';
import 'package:dolphincoder/features/videos/screens/video_detail_screen.dart';

class MockVideosAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  MockVideosAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      onFetch(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    DioClient.reset();
    DioClient.setToken('test-token');
  });

  group('VideoModel Serialization & Thumbnail Tests', () {
    test('parses VideoModel and builds YouTube HQ thumbnail URL', () {
      final json = {
        '_id': 'vid_101',
        'title': 'German Pronunciation Guide',
        'youtubeVideoId': 'dQw4w9WgXcQ',
        'description': 'Learn Umlauts and Eszett',
        'viewCount': 420,
        'subject': {'name': 'German'},
        'topic': 'Phonetics',
        'tags': ['A1', 'Pronunciation'],
        'createdAt': '2026-10-30T12:00:00Z',
      };

      final video = VideoModel.fromJson(json);
      expect(video.id, 'vid_101');
      expect(video.title, 'German Pronunciation Guide');
      expect(video.youtubeVideoId, 'dQw4w9WgXcQ');
      expect(video.viewCount, 420);
      expect(video.subjectName, 'German');
      expect(video.topic, 'Phonetics');
      expect(video.tags, ['A1', 'Pronunciation']);
      expect(
        video.thumbnailUrl,
        'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      );
    });
  });

  group('VideosRepository & VideosListNotifier Tests', () {
    test('fetches videos list and handles search queries', () async {
      String? lastQuery;
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockVideosAdapter((options) async {
        if (options.path.contains(ApiConstants.videos)) {
          lastQuery = options.queryParameters['q']?.toString();
          return ResponseBody.fromString(
            jsonEncode({
              'videos': [
                {
                  '_id': 'v1',
                  'title': 'Modal Verbs in German',
                  'youtubeVideoId': 'abc123xyz00',
                  'viewCount': 15,
                  'createdAt': '2026-10-30',
                }
              ],
            }),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString('{}', 404);
      });

      final repo = VideosRepository();
      final notifier = VideosListNotifier(repo);
      await notifier.fetch();

      expect(notifier.state.videos.length, 1);
      expect(notifier.state.videos.first.title, 'Modal Verbs in German');

      notifier.search('Modal');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(lastQuery, 'Modal');
    });
  });

  group('VideoDetailScreen Widget Tests', () {
    testWidgets('renders video details without WebView player', (tester) async {
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockVideosAdapter((options) async {
        if (options.path.contains('${ApiConstants.videos}/v_detail_1')) {
          return ResponseBody.fromString(
            jsonEncode({
              'video': {
                '_id': 'v_detail_1',
                'title': 'Separable Verbs Masterclass',
                'youtubeVideoId': 'xyz987abc',
                'description': 'Understand trennbare Verben in German A1.',
                'viewCount': 88,
                'subject': {'name': 'German'},
                'topic': 'Verbs',
                'tags': ['A1', 'Grammar'],
                'createdAt': '2026-10-30T12:00:00Z',
              }
            }),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString('{}', 404);
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: VideoDetailScreen(videoId: 'v_detail_1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Separable Verbs Masterclass'), findsWidgets);
      expect(find.text('88 views'), findsOneWidget);
      expect(find.text('Understand trennbare Verben in German A1.'), findsOneWidget);
      expect(find.text('#A1'), findsOneWidget);
    });
  });
}
