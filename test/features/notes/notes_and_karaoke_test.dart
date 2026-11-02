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
import 'package:dolphincoder/features/notes/data/models/karaoke_model.dart';
import 'package:dolphincoder/features/notes/data/models/note_model.dart';
import 'package:dolphincoder/features/notes/data/notes_repository.dart';
import 'package:dolphincoder/features/notes/providers/notes_provider.dart';

class MockNotesAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  MockNotesAdapter(this.onFetch);

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

  group('NoteModel & KaraokeStory Serialization Tests', () {
    test('parses rich-text and karaoke notes with nested sentences and words', () {
      final json = {
        '_id': 'note_55',
        'title': 'Im Café bestellen',
        'content': '<p>Guten Morgen!</p>',
        'contentType': 'karaoke',
        'isPinned': true,
        'tags': ['A1', 'Dialog'],
        'subject': {'name': 'German'},
        'createdAt': '2026-10-30T10:00:00Z',
        'duration': 14.5,
        'karaokeData': {
          'title': 'Im Café bestellen',
          'englishTitle': 'Ordering at the Café',
          'audioUrl': '/api/notes/audio/db/12',
          'duration': 14.5,
          'isSprechen': true,
          'vocab': {
            'kaffee': {'meaning': 'Coffee', 'article': 'der'},
          },
          'sentences': [
            {
              'index': 0,
              'text': 'Ich möchte einen Kaffee.',
              'translation': 'I would like a coffee.',
              'speaker': 'Anna',
              'start': 0.5,
              'end': 3.2,
              'words': [
                {'word': 'Ich', 'clean': 'ich', 'start': 0.5, 'end': 0.9, 'sentenceIndex': 0},
                {'word': 'möchte', 'clean': 'möchte', 'start': 1.0, 'end': 1.6, 'sentenceIndex': 0},
              ],
            }
          ],
        },
      };

      final note = NoteModel.fromJson(json);
      expect(note.id, 'note_55');
      expect(note.title, 'Im Café bestellen');
      expect(note.isKaraoke, isTrue);
      expect(note.isPinned, isTrue);
      expect(note.tags, ['A1', 'Dialog']);
      expect(note.subjectName, 'German');
      expect(note.karaokeData, isNotNull);

      final story = note.karaokeData!;
      expect(story.englishTitle, 'Ordering at the Café');
      expect(story.isSprechen, isTrue);
      expect(story.sentences.length, 1);
      expect(story.sentences.first.text, 'Ich möchte einen Kaffee.');
      expect(story.sentences.first.words.length, 2);
      expect(story.sentences.first.words.first.word, 'Ich');
    });

    test('parses stringified karaokeData JSON gracefully', () {
      final json = {
        'id': 'note_56',
        'title': 'Stringified Karaoke',
        'content': '',
        'contentType': 'richtext',
        'createdAt': '2026-10-30T10:00:00Z',
        'karaokeData': jsonEncode({
          'title': 'Encoded Story',
          'sentences': [],
        }),
      };

      final note = NoteModel.fromJson(json);
      expect(note.isKaraoke, isTrue);
      expect(note.karaokeData?.title, 'Encoded Story');
    });
  });

  group('NotesRepository & NotesListNotifier Tests', () {
    test('fetches paginated notes and filters by search query and subject', () async {
      Map<String, dynamic>? lastParams;
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockNotesAdapter((options) async {
        if (options.path.contains(ApiConstants.notes)) {
          lastParams = options.queryParameters;
          return ResponseBody.fromString(
            jsonEncode({
              'notes': [
                {
                  '_id': 'n1',
                  'title': 'German Articles: Der, Die, Das',
                  'content': 'Grammar summary',
                  'contentType': 'richtext',
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

      final repo = NotesRepository();
      final notifier = NotesListNotifier(repo);
      await notifier.fetch();

      expect(notifier.state.notes.length, 1);
      expect(notifier.state.notes.first.title, 'German Articles: Der, Die, Das');

      notifier.search('Articles');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(lastParams?['q'], 'Articles');

      notifier.filterSubject('subj_de');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(lastParams?['subject'], 'subj_de');
    });
  });
}
