import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolphincoder/core/constants/api_constants.dart';
import 'package:dolphincoder/core/network/dio_client.dart';
import 'package:dolphincoder/core/services/cache_service.dart';
import 'package:dolphincoder/features/auth/screens/language_selection_screen.dart';
import 'package:dolphincoder/features/gamification/data/gamification_repository.dart';
import 'package:dolphincoder/features/gamification/data/models/gamification_models.dart';
import 'package:dolphincoder/features/gamification/providers/gamification_provider.dart';
import 'package:dolphincoder/features/gamification/screens/lesson_session_screen.dart';

class _MockGamificationHttpAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  _MockGamificationHttpAdapter(this.onFetch);

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

class _FakePlacementRepository extends GamificationRepository {
  _FakePlacementRepository({
    required this.placementLessonResponse,
    this.pathNodesToReturn = const [],
    this.statusTargetLanguage = 'en',
    this.statusNativeLanguage = 'hi',
  });

  final Map<String, dynamic> placementLessonResponse;
  final List<PathNodeModel> pathNodesToReturn;
  final String statusTargetLanguage;
  final String statusNativeLanguage;

  int deductOxygenCalls = 0;
  int completeNodeCalls = 0;
  int getPlacementLessonCalls = 0;
  Map<String, dynamic>? lastEvaluatePayload;
  List<Map<String, int?>> getPathWindowsRequested = [];

  @override
  Future<GamificationStatusModel> getStatus() async {
    return GamificationStatusModel(
      targetLanguage: statusTargetLanguage,
      nativeLanguage: statusNativeLanguage,
      currentLevel: 'A1',
      oxygen: 5,
      pearls: 100,
    );
  }

  @override
  Future<bool> switchCourse({
    required String targetLanguage,
    required String nativeLanguage,
    String level = 'A1',
  }) async =>
      true;

  @override
  Future<List<PathNodeModel>> getPath({
    String? targetLanguage,
    String? nativeLanguage,
    String? level,
    int? section,
    int? unit,
    int? startUnit,
    int? endUnit,
  }) async {
    getPathWindowsRequested.add({'startUnit': startUnit, 'endUnit': endUnit});
    return pathNodesToReturn;
  }

  @override
  Future<Map<String, dynamic>> getPlacementLesson({
    required String targetLanguage,
    required String nativeLanguage,
    String level = 'A1',
  }) async {
    getPlacementLessonCalls++;
    return placementLessonResponse;
  }

  @override
  Future<Map<String, dynamic>> evaluatePlacement({
    required int scorePct,
    required int correctCount,
    required int totalQuestions,
    required String targetLanguage,
    required String nativeLanguage,
    int? mistakesCount,
    String? placementMode,
    dynamic lessonId,
  }) async {
    lastEvaluatePayload = {
      'scorePct': scorePct,
      'correctCount': correctCount,
      'totalQuestions': totalQuestions,
      'targetLanguage': targetLanguage,
      'nativeLanguage': nativeLanguage,
      'mistakesCount': mistakesCount,
      'placementMode': placementMode,
      'lessonId': lessonId,
    };
    final gatePassed = (mistakesCount ?? 0) <= 3;
    return {
      'success': true,
      'passed': gatePassed,
      'placement': {
        'placementMode': placementMode ?? 'section2_gate',
        'passed': gatePassed,
        'assignedLevel': gatePassed ? 'SEC 2' : 'A1',
        'effectiveLevel': 'A1',
        'targetSectionNumber': gatePassed ? 2 : 1,
        'targetSectionTitle': gatePassed ? 'Explorer' : 'Rookie',
        'targetUnitNumber': 1,
        'placementSkipToNode': gatePassed ? 60 : 0,
      },
      'status': {
        'targetLanguage': targetLanguage,
        'nativeLanguage': nativeLanguage,
        'currentLevel': 'A1',
        'placementCompleted': true,
        'placementLevel': gatePassed ? 'SEC 2' : 'A1',
        'placementSkipToNode': gatePassed ? 60 : 0,
        'isAcceleratedFallback': gatePassed,
      },
    };
  }

  @override
  Future<bool> deductOxygen() async {
    deductOxygenCalls++;
    return true;
  }

  @override
  Future<Map<String, dynamic>> completeNode({
    required int nodeIndex,
    int scorePct = 100,
    String? attemptId,
    String? targetLanguage,
    String? nativeLanguage,
    String? level,
  }) async {
    completeNodeCalls++;
    return {'success': true};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    for (final channelName in const [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
      'flutter_tts',
      'com.llfbandit.record/messages',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        MethodChannel(channelName),
        (_) async => 1,
      );
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await CacheService().setActiveUser('placement_gate_test_user');
  });

  group('Section 2 Gate Placement Flow', () {
    test('PathNodesNotifier fetches full path without endUnit cap when skipToNode > 0', () async {
      const skippedStatus = GamificationStatusModel(
        targetLanguage: 'en',
        nativeLanguage: 'hi',
        currentLevel: 'A1',
        placementCompleted: true,
        placementLevel: 'SEC 2',
        placementSkipToNode: 60,
        isAcceleratedFallback: true,
      );
      await CacheService().saveStatus(skippedStatus);

      final repo = _FakePlacementRepository(
        placementLessonResponse: const {'success': false},
        pathNodesToReturn: const [
          PathNodeModel(
            index: 60,
            title: 'Section 2 Start',
            subtitle: 'Explorer',
            type: 'lesson',
            status: 'available',
            sectionNumber: 2,
            sectionTitle: 'Explorer',
            sectionUnitNumber: 1,
            unitNumber: 1,
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [gamificationRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      // Initialize status and trigger path initialization.
      container.read(gamificationStatusProvider);
      container.read(pathNodesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(repo.getPathWindowsRequested, isNotEmpty);
      expect(repo.getPathWindowsRequested.first['startUnit'], isNull);
      expect(repo.getPathWindowsRequested.first['endUnit'], isNull);
      final nodes = container.read(pathNodesProvider).value ?? [];
      expect(nodes.any((n) => n.sectionNumber == 2 && n.status == 'available'), isTrue);
    });

    test('GamificationRepository sends section2_gate fields to backend endpoints', () async {
      final capturedRequests = <RequestOptions>[];
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = _MockGamificationHttpAdapter((options) async {
        capturedRequests.add(options);
        if (options.path.contains(ApiConstants.gamificationPlacementLesson)) {
          return ResponseBody.fromString(
            jsonEncode({
              'success': true,
              'placementMode': 'section2_gate',
              'lesson': {'id': 404, 'title': 'Shopping & Money • Lesson 4', 'stages': []},
            }),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString(
          jsonEncode({'success': true, 'passed': true}),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });
      DioClient.setInstance(dio);
      addTearDown(() => DioClient.setInstance(Dio()));

      final repo = GamificationRepository();
      final lessonRes = await repo.getPlacementLesson(
        targetLanguage: 'en',
        nativeLanguage: 'hi',
      );
      expect(lessonRes['success'], isTrue);
      expect(capturedRequests.last.queryParameters['targetLanguage'], 'en');
      expect(capturedRequests.last.queryParameters['nativeLanguage'], 'hi');

      final evalRes = await repo.evaluatePlacement(
        scorePct: 88,
        correctCount: 7,
        totalQuestions: 8,
        mistakesCount: 1,
        placementMode: 'section2_gate',
        lessonId: 404,
        targetLanguage: 'en',
        nativeLanguage: 'hi',
      );
      expect(evalRes['passed'], isTrue);
      expect(capturedRequests.last.data['placementMode'], 'section2_gate');
      expect(capturedRequests.last.data['mistakesCount'], 1);
      expect(capturedRequests.last.data['lessonId'], 404);
    });

    testWidgets(
      'LessonSessionScreen(isPlacementGate: true) preserves Oxygen on mistakes, evaluates Section 2 gate, and avoids XP/ad prompts',
      (tester) async {
        final fakeRepo = _FakePlacementRepository(
          placementLessonResponse: {
            'success': true,
            'placementMode': 'section2_gate',
            'passRules': {'minScorePct': 70, 'maxMistakes': 3},
            'lesson': {
              'id': 44,
              'title': 'Shopping & Money • Lesson 4',
              'stages': [
                {
                  'type': 'cloze_test',
                  'sentence': 'How _____ does this shirt cost?',
                  'translation': 'यह शर्ट कितने की है?',
                  'blank': 'much',
                  'options': ['much', 'many'],
                },
              ],
            },
          },
        );

        String? lastNavigatedRoute;
        final router = GoRouter(
          initialLocation: '/placement-lesson',
          routes: [
            GoRoute(
              path: '/placement-lesson',
              builder: (_, __) => const LessonSessionScreen(
                nodeIndex: 0,
                isPlacementGate: true,
                placementTargetLanguage: 'en',
                placementNativeLanguage: 'hi',
              ),
            ),
            GoRoute(
              path: '/home',
              builder: (_, __) {
                lastNavigatedRoute = '/home';
                return const Scaffold(body: Text('HOME_MAP'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              gamificationRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // AppBar renders SEC 2 gate try counter rather than Oxygen hearts.
        expect(find.text('SEC 2 • 3/3'), findsOneWidget);
        expect(find.byIcon(Icons.favorite_rounded), findsNothing);

        // Intentionally pick the wrong answer -> decrements remaining tries but NEVER deducts Oxygen.
        await tester.tap(find.text('many'));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.tap(find.text('CHECK ANSWER'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(fakeRepo.deductOxygenCalls, 0);
        expect(find.text('SEC 2 • 2/3'), findsOneWidget);

        // Advance past the feedback sheet -> enters 3s Mistakes Review interstitial.
        await tester.tap(find.text('CONTINUE →'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 3, milliseconds: 300));

        // Answer correctly on retry.
        await tester.tap(find.text('much'));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.tap(find.text('CHECK ANSWER'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('CONTINUE →'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Must evaluate placement gate (not completeNode), award 0 XP / no 2X ad button, and show unlock UI.
        expect(fakeRepo.completeNodeCalls, 0);
        expect(fakeRepo.lastEvaluatePayload?['placementMode'], 'section2_gate');
        expect(fakeRepo.lastEvaluatePayload?['mistakesCount'], 1);
        expect(fakeRepo.lastEvaluatePayload?['lessonId'], 44);

        expect(find.text('SECTION 2 UNLOCKED!'), findsOneWidget);
        expect(find.textContaining('2X BONUS XP'), findsNothing);
        expect(find.text('TOTAL XP'), findsNothing);

        await tester.tap(find.text('START IN SECTION 2'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(lastNavigatedRoute, '/home');
        expect(find.text('HOME_MAP'), findsOneWidget);

        // Advance FakeAsync past audioplayers' internal 30s prepare timeout timers.
        await tester.pump(const Duration(seconds: 31));
      },
    );

    testWidgets(
      'LessonSessionScreen(isPlacementGate: true) handles missing Section 2 lesson cleanly',
      (tester) async {
        final fakeRepo = _FakePlacementRepository(
          placementLessonResponse: {
            'success': false,
            'code': 'PLACEMENT_LESSON_UNAVAILABLE',
            'message': 'Section 2 placement lesson is not published for this course yet.',
          },
        );

        final router = GoRouter(
          initialLocation: '/placement-lesson',
          routes: [
            GoRoute(
              path: '/placement-lesson',
              builder: (_, __) => const LessonSessionScreen(
                nodeIndex: 0,
                isPlacementGate: true,
                placementTargetLanguage: 'de',
                placementNativeLanguage: 'en',
              ),
            ),
            GoRoute(
              path: '/home',
              builder: (_, __) => const Scaffold(body: Text('HOME_FALLBACK')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              gamificationRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Starting at Unit 1'), findsOneWidget);
        await tester.tap(find.text('CONTINUE TO MAP'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('HOME_FALLBACK'), findsOneWidget);
      },
    );

    testWidgets(
      'LanguageSelectionScreen navigates to /placement-lesson when placement mode is selected',
      (tester) async {
        final fakeRepo = _FakePlacementRepository(
          placementLessonResponse: {'success': false},
        );
        String? targetRouteExtraLang;
        bool visitedPlacementLesson = false;

        final router = GoRouter(
          initialLocation: '/language-select',
          routes: [
            GoRoute(
              path: '/language-select',
              builder: (_, __) => const LanguageSelectionScreen(),
            ),
            GoRoute(
              path: '/placement-lesson',
              builder: (_, state) {
                visitedPlacementLesson = true;
                final extra = state.extra as Map<String, dynamic>?;
                targetRouteExtraLang = extra?['targetLanguage']?.toString();
                return const Scaffold(body: Text('GATE_LESSON_ROUTE'));
              },
            ),
            GoRoute(
              path: '/placement-quiz',
              builder: (_, __) => const Scaffold(body: Text('LEGACY_QUIZ_ROUTE')),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              gamificationRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Step 0: Select German explicitly -> Continue to Step 1
        final germanFinder = find.textContaining('German', findRichText: true).first;
        await tester.ensureVisible(germanFinder);
        await tester.tap(germanFinder);
        await tester.pump(const Duration(milliseconds: 150));
        await tester.tap(find.text('CONTINUE'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Step 1: Continue with English -> Step 2 (Starting point)
        await tester.tap(find.text('CONTINUE'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Step 2: Select "Already know some German?" placement option
        final placementCardFinder = find.text('Solve Section 2, Unit 4, Lesson 4 to start in Section 2');
        await tester.ensureVisible(placementCardFinder);
        await tester.tap(placementCardFinder);
        await tester.pump(const Duration(milliseconds: 150));

        await tester.tap(find.text('START PLACEMENT TEST 🎯'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(visitedPlacementLesson, isTrue);
        expect(targetRouteExtraLang, 'de');
        expect(find.text('GATE_LESSON_ROUTE'), findsOneWidget);
        expect(find.text('LEGACY_QUIZ_ROUTE'), findsNothing);
      },
    );

    testWidgets(
      'Regular LessonSessionScreen filters out karaoke stage and tapping CAN\'T SPEAK RIGHT NOW finishes without Audio-Karaoke Rhythmus',
      (tester) async {
        tester.view.physicalSize = const Size(800, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final fakeRepo = _FakePlacementRepository(
          placementLessonResponse: const {'success': false},
          statusTargetLanguage: 'de',
          statusNativeLanguage: 'en',
        );

        const lessonNode = PathNodeModel(
          index: 0,
          id: 10458,
          title: 'Basics & Greetings',
          subtitle: 'Unit 1 • Lesson 1',
          type: 'lesson',
          status: 'available',
          stages: [
            {
              'type': 'sprechen',
              'prompt': 'Ja und nein.',
              'translation': 'Yes and no.',
              'minAccuracy': 75,
              'audioUrl': '',
            },
            {
              'type': 'karaoke',
              'storyText': 'Hallo! Ja und nein. Hallo und ja. Hallo und nein.',
              'translationText': 'Hello! Yes and no.',
              'audioUrl': '',
            },
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              gamificationRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: LessonSessionScreen(
                nodeIndex: 0,
                node: lessonNode,
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Speaking stage must keep the skip option visible and never include karaoke.
        expect(find.text("CAN'T SPEAK RIGHT NOW"), findsOneWidget);
        expect(find.text('Audio-Karaoke Rhythmus'), findsNothing);
        expect(find.text('Audio Karaoke Rhythm'), findsNothing);

        final skipBtn = find.text("CAN'T SPEAK RIGHT NOW");
        await tester.ensureVisible(skipBtn);
        await tester.tap(skipBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Advancing from sprechen must finish the lesson directly instead of showing karaoke.
        expect(find.text('Audio-Karaoke Rhythmus'), findsNothing);
        expect(find.text('Audio Karaoke Rhythm'), findsNothing);
        expect(find.text('LESSON COMPLETE!'), findsOneWidget);
        expect(find.text('CONTINUE TO MAP'), findsOneWidget);

        // Flush pending audio/speech timers cleanly inside FakeAsync.
        await tester.pump(const Duration(seconds: 31));
      },
    );

    testWidgets(
      'LessonSessionScreen(isPlacementGate: true) fails Section 2 gate when exceeding 3 mistakes without deducting Oxygen',
      (tester) async {
        tester.view.physicalSize = const Size(800, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeRepo = _FakePlacementRepository(
          placementLessonResponse: {
            'success': true,
            'placementMode': 'section2_gate',
            'passRules': {'minScorePct': 70, 'maxMistakes': 3},
            'lesson': {
              'id': 45,
              'title': 'Section 2 Fail Path',
              'stages': [
                {
                  'type': 'cloze_test',
                  'sentence': 'How ___ does it cost?',
                  'translation': 'Wie viel kostet das?',
                  'blank': 'much',
                  'options': ['much', 'many'],
                },
              ],
            },
          },
        );

        String? lastNavigatedRoute;
        final router = GoRouter(
          initialLocation: '/placement-lesson',
          routes: [
            GoRoute(
              path: '/placement-lesson',
              builder: (_, __) => const LessonSessionScreen(
                nodeIndex: 0,
                isPlacementGate: true,
                placementTargetLanguage: 'de',
                placementNativeLanguage: 'en',
              ),
            ),
            GoRoute(
              path: '/home',
              builder: (_, __) {
                lastNavigatedRoute = '/home';
                return const Scaffold(body: Text('HOME_MAP'));
              },
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              gamificationRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('SEC 2 • 3/3'), findsOneWidget);
        expect(find.byIcon(Icons.favorite_rounded), findsNothing);

        // Exceed the 3-mistake ceiling (4 wrong answers) -> never deducts global Oxygen.
        for (var attempt = 0; attempt < 4; attempt++) {
          await tester.tap(find.text('many'));
          await tester.pump(const Duration(milliseconds: 150));
          await tester.tap(find.text('CHECK ANSWER'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));

          expect(fakeRepo.deductOxygenCalls, 0);
          final expectedRemaining = (3 - (attempt + 1)).clamp(0, 3);
          expect(find.text('SEC 2 • $expectedRemaining/3'), findsOneWidget);

          await tester.tap(find.text('CONTINUE →'));
          await tester.pump();
          await tester.pump(const Duration(seconds: 3, milliseconds: 300));
        }

        // Answer correctly on final retry to trigger gate evaluation.
        await tester.tap(find.text('much'));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.tap(find.text('CHECK ANSWER'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        await tester.tap(find.text('CONTINUE →'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(fakeRepo.deductOxygenCalls, 0);
        expect(fakeRepo.completeNodeCalls, 0);
        expect(fakeRepo.lastEvaluatePayload?['placementMode'], 'section2_gate');
        expect(fakeRepo.lastEvaluatePayload?['mistakesCount'], 4);
        expect(fakeRepo.lastEvaluatePayload?['lessonId'], 45);

        expect(find.text('STARTING AT SECTION 1'), findsOneWidget);
        expect(find.text('SECTION 2 UNLOCKED!'), findsNothing);
        expect(find.text('4/3'), findsOneWidget);
        expect(find.text('Sec 1'), findsOneWidget);
        expect(find.text('START AT UNIT 1'), findsOneWidget);

        await tester.tap(find.text('START AT UNIT 1'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(lastNavigatedRoute, '/home');
        expect(find.text('HOME_MAP'), findsOneWidget);

        await tester.pump(const Duration(seconds: 31));
      },
    );

    testWidgets(
      'Regular LessonSessionScreen strips legacy karaoke stage loaded from Tier-2 disk cache',
      (tester) async {
        tester.view.physicalSize = const Size(800, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await CacheService().saveLessonDetails(555, {
          'id': 555,
          'updatedAt': '2026-11-12T00:00:00.000Z',
          'stages': [
            {
              'type': 'sprechen',
              'prompt': 'Guten Tag.',
              'translation': 'Good day.',
              'minAccuracy': 75,
              'audioUrl': '',
            },
            {
              'type': 'karaoke',
              'storyText': 'Hallo! Ja und nein.',
              'translationText': 'Hello!',
              'audioUrl': '',
            },
          ],
        });

        final fakeRepo = _FakePlacementRepository(
          placementLessonResponse: const {'success': false},
          statusTargetLanguage: 'de',
          statusNativeLanguage: 'en',
        );
        const cachedNode = PathNodeModel(
          index: 0,
          id: 555,
          title: 'Cached Lesson',
          subtitle: 'Unit 1',
          type: 'lesson',
          status: 'available',
          updatedAt: '2026-11-12T00:00:00.000Z',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              gamificationRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: LessonSessionScreen(nodeIndex: 0, node: cachedNode),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Guten'), findsOneWidget);
        expect(find.text('Tag.'), findsOneWidget);
        expect(find.text("CAN'T SPEAK RIGHT NOW"), findsOneWidget);
        expect(find.text('Audio-Karaoke Rhythmus'), findsNothing);
        expect(find.text('Audio Karaoke Rhythm'), findsNothing);

        final skipBtn = find.text("CAN'T SPEAK RIGHT NOW");
        await tester.ensureVisible(skipBtn);
        await tester.tap(skipBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Audio-Karaoke Rhythmus'), findsNothing);
        expect(find.text('Audio Karaoke Rhythm'), findsNothing);
        expect(find.text('LESSON COMPLETE!'), findsOneWidget);
        expect(find.text('CONTINUE TO MAP'), findsOneWidget);

        await tester.pump(const Duration(seconds: 31));
      },
    );

    testWidgets(
      'Snoozed speaking persists across consecutive lessons and Resume Speaking restores CAN\'T SPEAK RIGHT NOW',
      (tester) async {
        tester.view.physicalSize = const Size(800, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeRepo = _FakePlacementRepository(
          placementLessonResponse: const {'success': false},
          statusTargetLanguage: 'de',
          statusNativeLanguage: 'en',
        );

        // Lesson 1: Tap CAN'T SPEAK RIGHT NOW -> snoozes speaking & completes lesson cleanly.
        const lesson1Node = PathNodeModel(
          index: 0,
          id: 701,
          title: 'Lesson 1',
          subtitle: 'Unit 1',
          type: 'lesson',
          status: 'available',
          stages: [
            {
              'type': 'sprechen',
              'prompt': 'Hallo.',
              'translation': 'Hello.',
              'minAccuracy': 75,
              'audioUrl': '',
            },
            {
              'type': 'karaoke',
              'storyText': 'Hallo! Ja und nein.',
              'translationText': 'Hello!',
              'audioUrl': '',
            },
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('scope-lesson-1'),
            overrides: [
              gamificationRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: LessonSessionScreen(nodeIndex: 0, node: lesson1Node),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text("CAN'T SPEAK RIGHT NOW"), findsOneWidget);

        final skipBtn = find.text("CAN'T SPEAK RIGHT NOW");
        await tester.ensureVisible(skipBtn);
        await tester.tap(skipBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Audio-Karaoke Rhythmus'), findsNothing);
        expect(find.text('LESSON COMPLETE!'), findsOneWidget);
        final prefs = await SharedPreferences.getInstance();
        expect(
          (prefs.getInt('pref_speaking_muted_until_ms') ?? 0) >
              DateTime.now().millisecondsSinceEpoch,
          isTrue,
        );
        await tester.pump(const Duration(seconds: 31));

        // Lesson 2: Fresh ProviderScope loads persisted snooze -> renders paused card & Continue finishes without karaoke.
        const lesson2Node = PathNodeModel(
          index: 1,
          id: 702,
          title: 'Lesson 2',
          subtitle: 'Unit 1',
          type: 'lesson',
          status: 'available',
          stages: [
            {
              'type': 'karaoke',
              'storyText': 'Hallo! Ja und nein.',
              'translationText': 'Hello!',
              'audioUrl': '',
            },
            {
              'type': 'sprechen',
              'prompt': 'Wie geht es?',
              'translation': 'How are you?',
              'minAccuracy': 75,
              'audioUrl': '',
            },
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('scope-lesson-2'),
            overrides: [
              gamificationRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: LessonSessionScreen(nodeIndex: 1, node: lesson2Node),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Speaking Exercises Paused'), findsOneWidget);
        expect(find.text('Resume Speaking'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
        expect(find.text("CAN'T SPEAK RIGHT NOW"), findsNothing);
        expect(find.text('Audio-Karaoke Rhythmus'), findsNothing);

        await tester.tap(find.text('Continue'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Audio-Karaoke Rhythmus'), findsNothing);
        expect(find.text('LESSON COMPLETE!'), findsOneWidget);
        await tester.pump(const Duration(seconds: 31));

        // Lesson 3: Fresh ProviderScope still sees snooze; Resume Speaking unmutes and restores CAN'T SPEAK RIGHT NOW.
        const lesson3Node = PathNodeModel(
          index: 2,
          id: 703,
          title: 'Lesson 3',
          subtitle: 'Unit 1',
          type: 'lesson',
          status: 'available',
          stages: [
            {
              'type': 'sprechen',
              'prompt': 'Tschuess.',
              'translation': 'Bye.',
              'minAccuracy': 75,
              'audioUrl': '',
            },
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('scope-lesson-3'),
            overrides: [
              gamificationRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: LessonSessionScreen(nodeIndex: 2, node: lesson3Node),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Speaking Exercises Paused'), findsOneWidget);

        await tester.tap(find.text('Resume Speaking'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Speaking Exercises Paused'), findsNothing);
        expect(find.text('Tschuess.'), findsOneWidget);
        expect(find.text("CAN'T SPEAK RIGHT NOW"), findsOneWidget);

        await tester.pump(const Duration(seconds: 31));
      },
    );
  });
}
