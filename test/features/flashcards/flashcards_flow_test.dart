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
import 'package:dolphincoder/features/flashcards/data/flashcard_repository.dart';
import 'package:dolphincoder/features/flashcards/data/models/flashcard_model.dart';
import 'package:dolphincoder/features/flashcards/providers/difficult_words_provider.dart';
import 'package:dolphincoder/features/flashcards/providers/flashcard_provider.dart';
import 'package:dolphincoder/features/flashcards/screens/flashcards_screen.dart';

class MockFlashcardAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  MockFlashcardAdapter(this.onFetch);

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
  });

  group('FlashcardDeck & Flashcard Model Tests', () {
    test('deserializes deck and cards with both _id and id keys', () {
      final json = {
        '_id': 'deck_1',
        'deckName': 'German Core Verbs',
        'description': 'Top 50 German verbs',
        'color': '#06B6D4',
        'isPublic': true,
        'cards': [
          {'_id': 'c1', 'front': 'gehen', 'back': 'to go', 'hint': 'irregular'},
          {'id': 'c2', 'front': 'kommen', 'back': 'to come'},
        ],
      };

      final deck = FlashcardDeck.fromJson(json);
      expect(deck.id, 'deck_1');
      expect(deck.deckName, 'German Core Verbs');
      expect(deck.cardCount, 2);
      expect(deck.cards.length, 2);
      expect(deck.cards[0].id, 'c1');
      expect(deck.cards[0].front, 'gehen');
      expect(deck.cards[0].back, 'to go');
      expect(deck.cards[0].hint, 'irregular');
      expect(deck.cards[1].id, 'c2');
    });
  });

  group('StudySessionNotifier Tests', () {
    test('manages card flip, hint, rating, next/prev navigation, and completion', () {
      final notifier = StudySessionNotifier();
      expect(notifier.state.currentIndex, 0);
      expect(notifier.state.isFlipped, isFalse);
      expect(notifier.state.showHint, isFalse);

      notifier.flip();
      expect(notifier.state.isFlipped, isTrue);

      notifier.showHint();
      expect(notifier.state.showHint, isTrue);

      // Rate card 1 as known out of 2 cards
      notifier.rate('c1', 'known', 2);
      expect(notifier.state.currentIndex, 1);
      expect(notifier.state.isFlipped, isFalse);
      expect(notifier.state.isComplete, isFalse);
      expect(notifier.state.masteredCount(), 1);

      // Navigate back and forth
      notifier.prev();
      expect(notifier.state.currentIndex, 0);
      notifier.next(2);
      expect(notifier.state.currentIndex, 1);

      // Rate final card as unknown -> session completes
      notifier.rate('c2', 'unknown', 2);
      expect(notifier.state.isComplete, isTrue);
      expect(notifier.state.masteredCount(), 1);

      // Restart resets state
      notifier.restart();
      expect(notifier.state.currentIndex, 0);
      expect(notifier.state.isComplete, isFalse);
      expect(notifier.state.cardResults, isEmpty);

      // Calling next(totalCards) on the last card (currentIndex == totalCards - 1) marks session complete
      notifier.next(2);
      expect(notifier.state.currentIndex, 1);
      expect(notifier.state.isComplete, isFalse);
      expect(notifier.state.isCompleted, isFalse);
      notifier.next(2);
      expect(notifier.state.isComplete, isTrue);
      expect(notifier.state.isCompleted, isTrue);
    });
  });

  group('DifficultWordsState & Notifier Tests', () {
    test('tracks bookmarked fronts case-insensitively and computes active volume', () async {
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockFlashcardAdapter((options) async {
        if (options.path.contains(ApiConstants.flashcards)) {
          return ResponseBody.fromString(
            jsonEncode({
              'decks': [
                {
                  '_id': 'diff_vol_1',
                  'deckName': 'Difficult Words - Vol 1',
                  'cards': [
                    {'_id': 'c1', 'front': 'Entschuldigung', 'back': 'Excuse me'},
                    {'_id': 'c2', 'front': 'Krankenhaus', 'back': 'Hospital'},
                  ],
                }
              ],
            }),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        }
        return ResponseBody.fromString('{}', 404);
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(difficultWordsProvider.notifier);
      await notifier.loadState();

      final state = container.read(difficultWordsProvider);
      expect(state.activeVolume, 1);
      expect(state.currentCardCount, 2);
      expect(state.activeDeckId, 'diff_vol_1');
      expect(state.isBookmarked('entschuldigung'), isTrue);
      expect(state.isBookmarked('KRANKENHAUS'), isTrue);
      expect(state.isBookmarked('Wasser'), isFalse);
    });
  });

  group('FlashcardsScreen Widget Tests', () {
    testWidgets('renders flashcard decks list from repository', (tester) async {
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockFlashcardAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'decks': [
              {
                '_id': 'deck_10',
                'deckName': 'A1 Everyday Phrases',
                'description': 'Essential phrases for beginners',
                'cardCount': 15,
                'cards': [
                  {'_id': 'c1', 'front': 'Guten Tag', 'back': 'Good day'},
                ],
              }
            ],
          }),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: FlashcardsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A1 Everyday Phrases'), findsOneWidget);
    });
  });
}
