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
import 'package:dolphincoder/features/quizzes/data/models/quiz_model.dart';
import 'package:dolphincoder/features/quizzes/data/quiz_repository.dart';
import 'package:dolphincoder/features/quizzes/providers/quiz_provider.dart';
import 'package:dolphincoder/features/quizzes/screens/quiz_result_screen.dart';
import 'package:dolphincoder/features/quizzes/screens/quiz_review_screen.dart';
import 'package:dolphincoder/features/quizzes/screens/quizzes_screen.dart';

class MockQuizAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  MockQuizAdapter(this.onFetch);

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

  group('QuizModel & QuizQuestion Serialization Tests', () {
    test('parses MCQ and match-pairs questions accurately', () {
      final json = {
        '_id': 'quiz_101',
        'title': 'German A1 Grammar Quiz',
        'description': 'Test your verb conjugations',
        'passingScore': 75,
        'timeLimit': 15,
        'totalPoints': 20,
        'subject': {'name': 'German'},
        'questions': [
          {
            '_id': 'q1',
            'text': 'What is "Hello" in German?',
            'type': 'multiple-choice',
            'options': ['Hallo', 'Tschüss', 'Danke', 'Bitte'],
            'correctIndex': 0,
            'points': 10,
          },
          {
            'id': 'q2',
            'question': 'Match the German pronouns',
            'type': 'match-pairs',
            'pairs': [
              {'left': 'Ich', 'right': 'I'},
              {'left': 'Du', 'right': 'You'},
            ],
            'leftItems': ['Ich', 'Du'],
            'rightItems': ['You', 'I'],
            'points': 10,
          },
        ],
      };

      final quiz = QuizModel.fromJson(json);
      expect(quiz.id, 'quiz_101');
      expect(quiz.title, 'German A1 Grammar Quiz');
      expect(quiz.passingScore, 75);
      expect(quiz.timeLimit, 15);
      expect(quiz.subjectName, 'German');
      expect(quiz.difficulty, 'Easy'); // <= 5 questions
      expect(quiz.questions.length, 2);

      final q1 = quiz.questions[0];
      expect(q1.id, 'q1');
      expect(q1.isMatchPairs, isFalse);
      expect(q1.options, ['Hallo', 'Tschüss', 'Danke', 'Bitte']);
      expect(q1.correctIndex, 0);

      final q2 = quiz.questions[1];
      expect(q2.id, 'q2');
      expect(q2.isMatchPairs, isTrue);
      expect(q2.pairs.length, 2);
      expect(q2.pairs.first.left, 'Ich');
      expect(q2.pairs.first.right, 'I');
    });

    test('computes difficulty tier based on question count', () {
      final easyQuiz = QuizModel(
        id: '1',
        title: 'Easy',
        questions: List.generate(4, (i) => QuizQuestion(id: '$i', text: 'Q', type: 'mcq')),
      );
      final mediumQuiz = QuizModel(
        id: '2',
        title: 'Medium',
        questions: List.generate(10, (i) => QuizQuestion(id: '$i', text: 'Q', type: 'mcq')),
      );
      final hardQuiz = QuizModel(
        id: '3',
        title: 'Hard',
        questions: List.generate(20, (i) => QuizQuestion(id: '$i', text: 'Q', type: 'mcq')),
      );

      expect(easyQuiz.difficulty, 'Easy');
      expect(mediumQuiz.difficulty, 'Medium');
      expect(hardQuiz.difficulty, 'Hard');
    });

    test('parses AttemptModel and AttemptAnswer from backend payload', () {
      final json = {
        '_id': 'attempt_1',
        'score': 18,
        'maxScore': 20,
        'percentage': 90.0,
        'passed': true,
        'timeTakenSecs': 125,
        'answers': [
          {
            'questionId': 'q1',
            'chosenIndex': 0,
            'isCorrect': true,
            'correctIndex': 0,
            'pointsEarned': 10,
          },
          {
            'questionId': 'q2',
            'isCorrect': true,
            'matches': [
              {'left': 'Ich', 'right': 'I'},
              {'left': 'Du', 'right': 'You'},
            ],
            'correctCount': 2,
            'totalPairs': 2,
            'pointsEarned': 8,
          },
        ],
      };

      final attempt = AttemptModel.fromJson(json);
      expect(attempt.id, 'attempt_1');
      expect(attempt.score, 18);
      expect(attempt.maxScore, 20);
      expect(attempt.percentage, 90.0);
      expect(attempt.passed, isTrue);
      expect(attempt.timeTaken, 125);
      expect(attempt.answers.length, 2);
      expect(attempt.answers[0].selectedIndex, 0);
      expect(attempt.answers[0].correct, isTrue);
      expect(attempt.answers[1].matches.length, 2);
      expect(attempt.answers[1].correctCount, 2);
    });
  });

  group('QuizTakeNotifier State Machine Tests', () {
    test('manages timer, answer selection, match answers, review flags, and navigation', () {
      final notifier = QuizTakeNotifier();
      notifier.init(10); // 10 minutes = 600 seconds
      expect(notifier.state.secondsRemaining, 600);
      expect(notifier.state.currentIndex, 0);

      // Select MCQ answer
      notifier.selectAnswer('q1', 2);
      expect(notifier.state.selectedAnswers['q1'], 2);

      // Set match-pairs answer
      notifier.setMatchAnswer('q2', [
        {'left': 'Hund', 'right': 'Dog'},
      ]);
      expect(notifier.state.matchAnswers['q2']?.first['right'], 'Dog');

      // Toggle review flag
      notifier.toggleReview('q1');
      expect(notifier.state.markedForReview.contains('q1'), isTrue);
      notifier.toggleReview('q1');
      expect(notifier.state.markedForReview.contains('q1'), isFalse);

      // Navigation bounds
      notifier.prev(); // at 0, stays at 0
      expect(notifier.state.currentIndex, 0);
      notifier.next(3);
      expect(notifier.state.currentIndex, 1);
      notifier.goTo(2);
      expect(notifier.state.currentIndex, 2);
      notifier.next(3); // at max index 2, stays at 2
      expect(notifier.state.currentIndex, 2);

      // Timer tick
      notifier.tick();
      expect(notifier.state.secondsRemaining, 599);
    });
  });

  group('QuizRepository & QuizzesListNotifier Tests', () {
    test('fetches quizzes list and handles search filter', () async {
      String? lastSearchQuery;
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockQuizAdapter((options) async {
        if (options.path.contains(ApiConstants.quizzes)) {
          lastSearchQuery = options.queryParameters['q']?.toString();
          return ResponseBody.fromString(
            jsonEncode({
              'quizzes': [
                {
                  '_id': 'qz_1',
                  'title': 'Vocabulary Basics',
                  'questions': [
                    {'_id': 'q1', 'text': 'Q1', 'type': 'multiple-choice'}
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

      final repo = QuizRepository();
      final notifier = QuizzesListNotifier(repo);
      await notifier.fetch();

      expect(notifier.state.quizzes.length, 1);
      expect(notifier.state.quizzes.first.title, 'Vocabulary Basics');

      notifier.search('Grammar');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(lastSearchQuery, 'Grammar');
    });
  });

  group('QuizzesScreen & QuizResultScreen Widget Tests', () {
    testWidgets('QuizzesScreen renders quiz cards from provider', (tester) async {
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockQuizAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({
            'quizzes': [
              {
                '_id': 'qz_10',
                'title': 'German Cases Masterclass',
                'description': 'Nominativ, Akkusativ, Dativ',
                'timeLimit': 10,
                'passingScore': 80,
                'questions': [
                  {'_id': '1', 'text': 'Q1', 'type': 'multiple-choice'},
                  {'_id': '2', 'text': 'Q2', 'type': 'multiple-choice'},
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
            home: QuizzesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('German Cases Masterclass'), findsOneWidget);
    });

    testWidgets('QuizResultScreen renders score, percentage, and pass banner', (tester) async {
      final dio = await DioClient.getInstance();
      dio.httpClientAdapter = MockQuizAdapter((options) async {
        return ResponseBody.fromString(
          jsonEncode({'decks': []}),
          200,
          headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
        );
      });

      final resultMap = <String, dynamic>{
        'score': 9,
        'maxScore': 10,
        'percentage': 90.0,
        'passed': true,
        'timeTaken': 65,
        'answers': const [
          AttemptAnswer(
            questionId: 'q1',
            selectedIndex: 1,
            correct: true,
            correctIndex: 1,
            pointsEarned: 9,
          ),
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: QuizResultScreen(
              quizId: 'qz_10',
              result: resultMap,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('90'), findsWidgets);
    });

    testWidgets(
      'QuizResultScreen counts match-pairs question (selectedIndex: -1, correct: true) as Correct (1) rather than Skipped',
      (tester) async {
        final dio = await DioClient.getInstance();
        dio.httpClientAdapter = MockQuizAdapter((options) async {
          return ResponseBody.fromString(
            jsonEncode({'decks': []}),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        });

        final resultMap = <String, dynamic>{
          'score': 5,
          'maxScore': 5,
          'percentage': 100.0,
          'passed': true,
          'timeTaken': 40,
          'questions': const [
            QuizQuestion(
              id: 'q_match_1',
              text: 'Match the German greetings',
              type: 'match-pairs',
              pairs: [
                QuizPairModel(left: 'Hallo', right: 'Hello'),
              ],
            ),
          ],
          'answers': const [
            AttemptAnswer(
              questionId: 'q_match_1',
              selectedIndex: -1,
              correct: true,
              matches: [
                QuizPairModel(left: 'Hallo', right: 'Hello'),
              ],
              correctCount: 1,
              totalPairs: 1,
              pointsEarned: 5,
            ),
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: QuizResultScreen(
                quizId: 'qz_match',
                result: resultMap,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Stats row should show 1 Correct and 0 Skipped, and question card should say 'Correct' not 'Skipped'
        expect(find.text('Not answered (Skipped)'), findsNothing);
        expect(find.text('Correct'), findsWidgets);
        // Verify the _StatMini above 'Correct' displays '1' and above 'Skipped' displays '0'
        final correctStatFinder = find.ancestor(
          of: find.text('Correct').first,
          matching: find.byType(Column),
        );
        expect(
          find.descendant(of: correctStatFinder.first, matching: find.text('1')),
          findsOneWidget,
        );
        final skippedStatFinder = find.ancestor(
          of: find.text('Skipped').first,
          matching: find.byType(Column),
        );
        expect(
          find.descendant(of: skippedStatFinder.first, matching: find.text('0')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'QuizReviewScreen renders MCQ question with List<String> options and correctIndex: 0 without TypeError crash',
      (tester) async {
        final dio = await DioClient.getInstance();
        dio.httpClientAdapter = MockQuizAdapter((options) async {
          if (options.path.contains('/review')) {
            return ResponseBody.fromString(
              jsonEncode({
                'result': {
                  'attempt': {
                    'score': 5,
                    'maxScore': 5,
                    'percentage': 100,
                    'passed': true,
                    'timeTakenSecs': 30,
                  },
                  'quiz': {
                    'title': 'German Greetings Review',
                  },
                  'questions': [
                    {
                      '_id': 'q1',
                      'text': 'What is "Good morning" in German?',
                      'type': 'multiple-choice',
                      'options': ['Guten Morgen', 'Gute Nacht'],
                      'correctIndex': 0,
                      'chosenIndex': 0,
                      'isCorrect': true,
                      'pointsEarned': 5,
                      'explanation': 'Guten Morgen means Good morning.',
                    },
                  ],
                },
              }),
              200,
              headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
            );
          }
          return ResponseBody.fromString(
            jsonEncode({'decks': []}),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        });

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: QuizReviewScreen(quizId: 'qz_rev_1'),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('German Greetings Review'), findsOneWidget);
        expect(find.text('What is "Good morning" in German?'), findsOneWidget);
        expect(find.text('Guten Morgen'), findsOneWidget);
        expect(find.text('Gute Nacht'), findsOneWidget);
      },
    );
  });
}
