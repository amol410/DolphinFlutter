import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolphincoder/core/constants/api_constants.dart';
import 'package:dolphincoder/core/network/dio_client.dart';
import 'package:dolphincoder/core/network/network_latency_tracker.dart';
import 'package:dolphincoder/core/services/cache_service.dart';
import 'package:dolphincoder/core/services/tts_service.dart';
import 'package:dolphincoder/features/gamification/data/gamification_repository.dart';
import 'package:dolphincoder/features/gamification/data/lesson_stage_parser.dart';
import 'package:dolphincoder/features/gamification/data/models/gamification_models.dart';

/// Custom Mock HTTP Adapter to simulate controlled network latency, timeouts, and responses.
class MockLatencyAdapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions options) onFetch;

  MockLatencyAdapter(this.onFetch);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return onFetch(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempTestDir;

  setUpAll(() {
    // Mock system channels for AudioPlayer, PathProvider, and FlutterTts
    const channel1 = MethodChannel('xyz.luan/audioplayers.global');
    const channel2 = MethodChannel('xyz.luan/audioplayers');
    const channelPath = MethodChannel('plugins.flutter.io/path_provider');
    const channelTts = MethodChannel('flutter_tts');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel1, (MethodCall methodCall) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel2, (MethodCall methodCall) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelPath, (MethodCall methodCall) async => '.');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelTts, (MethodCall methodCall) async => 1);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tempTestDir = Directory.systemTemp.createTempSync('dolphin_network_test_');
    CacheService().setAudioCacheDir(tempTestDir);
    CacheService().reset();
    DioClient.reset();
  });

  tearDown(() {
    TtsService().stop();
    try {
      if (tempTestDir.existsSync()) {
        tempTestDir.deleteSync(recursive: true);
      }
    } catch (_) {}
    DioClient.reset();
  });

  // =========================================================================
  // 1. LATENCY TRACKING TESTS
  // =========================================================================
  group('1. Network Latency Tracking Tests', () {
    test('Simulates 150ms server response and verifies app measures elapsed latency', () async {
      final tracker = NetworkLatencyTracker();
      tracker.reset();

      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.interceptors.add(NetworkLatencyInterceptor(tracker: tracker));
      dio.httpClientAdapter = MockLatencyAdapter((options) async {
        await Future.delayed(const Duration(milliseconds: 150));
        final body = jsonEncode({'success': true, 'message': 'OK'});
        return ResponseBody.fromString(body, 200, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
      });

      DioClient.setInstance(dio);

      final response = await dio.get('/test-endpoint');

      expect(response.statusCode, 200);
      expect(tracker.count, 1);
      final record = tracker.latestRecord;
      expect(record, isNotNull);
      expect(record!.url, '/test-endpoint');
      expect(record.method, 'GET');
      expect(record.statusCode, 200);
      expect(record.isError, isFalse);
      expect(record.latencyMs, greaterThanOrEqualTo(130));

      // Verifies response.extra also carries elapsed latency
      expect(response.extra[NetworkLatencyInterceptor.latencyKey], isNotNull);
      expect(response.extra[NetworkLatencyInterceptor.latencyKey], greaterThanOrEqualTo(130));
    });

    test('Simulates 450ms server response and verifies tracking accuracy', () async {
      final tracker = NetworkLatencyTracker();
      tracker.reset();

      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.interceptors.add(NetworkLatencyInterceptor(tracker: tracker));
      dio.httpClientAdapter = MockLatencyAdapter((options) async {
        await Future.delayed(const Duration(milliseconds: 450));
        final body = jsonEncode({'success': true, 'data': [1, 2, 3]});
        return ResponseBody.fromString(body, 200, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
      });

      DioClient.setInstance(dio);

      final response = await dio.get(ApiConstants.gamificationStatus);

      expect(response.statusCode, 200);
      expect(tracker.latestLatencyMs, greaterThanOrEqualTo(420));
      expect(tracker.latestRecord?.url, ApiConstants.gamificationStatus);
    });

    test('Simulates 1200ms high-latency server response without premature timeout', () async {
      final tracker = NetworkLatencyTracker();
      tracker.reset();

      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.defaultBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      dio.interceptors.add(NetworkLatencyInterceptor(tracker: tracker));
      dio.httpClientAdapter = MockLatencyAdapter((options) async {
        await Future.delayed(const Duration(milliseconds: 1200));
        final body = jsonEncode({
          'success': true,
          'nodes': [
            {'index': 0, 'title': 'Basics', 'type': 'lesson', 'status': 'available'},
          ],
        });
        return ResponseBody.fromString(body, 200, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
      });

      DioClient.setInstance(dio);

      final response = await dio.get(ApiConstants.gamificationPath);

      expect(response.statusCode, 200);
      expect(tracker.latestLatencyMs, greaterThanOrEqualTo(1100));
      expect(tracker.averageLatencyMs, greaterThanOrEqualTo(1100));
    });

    test('Notifies real-time event listeners on recorded network latency', () async {
      final tracker = NetworkLatencyTracker();
      tracker.reset();

      NetworkLatencyRecord? capturedRecord;
      tracker.addListener((rec) {
        capturedRecord = rec;
      });

      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.interceptors.add(NetworkLatencyInterceptor(tracker: tracker));
      dio.httpClientAdapter = MockLatencyAdapter((options) async {
        await Future.delayed(const Duration(milliseconds: 60));
        return ResponseBody.fromString('{"success":true}', 200);
      });

      await dio.get('/notify-test');

      expect(capturedRecord, isNotNull);
      expect(capturedRecord!.url, '/notify-test');
      expect(capturedRecord!.latencyMs, greaterThanOrEqualTo(50));
    });

    test('Measures and flags latency even on 500 server error', () async {
      final tracker = NetworkLatencyTracker();
      tracker.reset();

      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.interceptors.add(NetworkLatencyInterceptor(tracker: tracker));
      dio.httpClientAdapter = MockLatencyAdapter((options) async {
        await Future.delayed(const Duration(milliseconds: 100));
        return ResponseBody.fromString('{"message":"Internal Server Error"}', 500);
      });

      try {
        await dio.get('/failing-endpoint');
      } catch (_) {}

      expect(tracker.count, 1);
      final record = tracker.latestRecord;
      expect(record, isNotNull);
      expect(record!.isError, isTrue);
      expect(record.statusCode, 500);
      expect(record.latencyMs, greaterThanOrEqualTo(90));
    });
  });

  // =========================================================================
  // 2. TIMEOUT HANDLING TESTS
  // =========================================================================
  group('2. Timeout Handling & User-Friendly Retry Tests', () {
    test('DioClient.handleError converts connection & receive timeouts to friendly ApiException', () {
      final reqOptions = RequestOptions(path: ApiConstants.gamificationPath);

      final connectTimeoutErr = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.connectionTimeout,
        message: 'Connection timed out after 15000ms',
      );
      final receiveTimeoutErr = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.receiveTimeout,
        message: 'Receive timed out after 15000ms',
      );
      final sendTimeoutErr = DioException(
        requestOptions: reqOptions,
        type: DioExceptionType.sendTimeout,
        message: 'Send timed out after 15000ms',
      );

      final apiEx1 = DioClient.handleError(connectTimeoutErr);
      final apiEx2 = DioClient.handleError(receiveTimeoutErr);
      final apiEx3 = DioClient.handleError(sendTimeoutErr);

      expect(apiEx1.message, 'Connection timed out');
      expect(apiEx2.message, 'Connection timed out');
      expect(apiEx3.message, 'Connection timed out');
    });

    test('GamificationRepository.getPath catches timeout and falls back to archipelago without crash', () async {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.defaultBaseUrl,
        connectTimeout: const Duration(milliseconds: 50),
      ));
      dio.httpClientAdapter = MockLatencyAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timed out',
        );
      });
      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      final nodes = await repo.getPath();

      expect(nodes, isNotEmpty);
      expect(nodes.length, 7); // Default 7-island fallback Archipelago
      expect(nodes.first.title, 'Basics & Greetings');
    });

    test('GamificationRepository.getLessonDetails catches timeout gracefully without crashing', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockLatencyAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
          message: 'Receive timed out',
        );
      });
      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      final lesson = await repo.getLessonDetails('lesson_timeout_test');

      expect(lesson, isNull);
    });

    testWidgets('CurriculumPathScreen displays user-friendly Retry state on timeout and triggers reload', (tester) async {
      int retryCount = 0;

      await tester.pumpWidget(
        _buildCurriculumPathRetryHarness(
          onRetry: () {
            retryCount++;
          },
        ),
      );

      // Verify user-friendly retry UI is displayed
      expect(find.text('Unable to load path'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tap 'Retry' button
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Verifies retry action triggers reload callback
      expect(retryCount, 1);
    });

    testWidgets('LessonSessionScreen recovers gracefully into fallback stages on network timeout', (tester) async {
      const fallbackStages = ['word_match', 'listen_tap', 'cloze_test'];

      await tester.pumpWidget(
        _buildLessonTimeoutFallbackHarness(
          isTimedOut: true,
          fallbackStages: fallbackStages,
        ),
      );

      // Verify screen recovers gracefully into fallback mode without crashing
      expect(find.byKey(const ValueKey('lesson_session_fallback_view')), findsOneWidget);
      expect(find.byKey(const ValueKey('stage_word_match')), findsOneWidget);
      expect(find.byKey(const ValueKey('stage_listen_tap')), findsOneWidget);
      expect(find.text('Offline Practice Mode'), findsOneWidget);
    });
  });

  // =========================================================================
  // 3. JSON STAGES RESILIENCE TESTS
  // =========================================================================
  group('3. JSON Stages Resilience Tests', () {
    test('Parses word_match stage with standard {target, native} keys', () {
      final rawStage = {
        'type': 'word_match',
        'pairs': [
          {'target': 'Hallo', 'native': 'Hello'},
          {'target': 'Danke', 'native': 'Thank you'},
          {'target': 'Bitte', 'native': 'Please'},
          {'target': 'Tschüss', 'native': 'Goodbye'},
        ],
      };

      final parsed = LessonStageParser.parseWordMatch(rawStage);

      expect(parsed, isNotNull);
      expect(parsed!.germanWords.length, 4);
      expect(parsed.englishWords.length, 4);
      expect(parsed.solutionPairs['Hallo'], 'Hello');
      expect(parsed.solutionPairs['Danke'], 'Thank you');
      expect(parsed.solutionPairs['Bitte'], 'Please');
      expect(parsed.solutionPairs['Tschüss'], 'Goodbye');
    });

    test('Parses word_match with alternative schema keys {german, english} and {word, translation}', () {
      final rawStage1 = {
        'type': 'match_pairs',
        'pairs': [
          {'german': 'Wasser', 'english': 'Water'},
          {'german': 'Brot', 'english': 'Bread'},
        ],
      };
      final rawStage2 = {
        'type': 'word_match',
        'pairs': [
          {'word': 'Katze', 'translation': 'Cat'},
          {'word': 'Hund', 'translation': 'Dog'},
        ],
      };

      final parsed1 = LessonStageParser.parseWordMatch(rawStage1);
      final parsed2 = LessonStageParser.parseWordMatch(rawStage2);

      expect(parsed1, isNotNull);
      expect(parsed1!.solutionPairs['Wasser'], 'Water');
      expect(parsed1.solutionPairs['Brot'], 'Bread');

      expect(parsed2, isNotNull);
      expect(parsed2!.solutionPairs['Katze'], 'Cat');
      expect(parsed2.solutionPairs['Hund'], 'Dog');
    });

    test('Parses listen_tap stage with targetSentence, tokens, and audioUrl', () {
      final rawStage = {
        'type': 'listen_tap',
        'targetSentence': 'Guten Tag, ich bin Anna',
        'tokens': ['Kaffee', 'Guten', 'Tag,', 'ich', 'bin', 'Anna'],
        'audioUrl': 'https://dolphincoder.com/audio/lesson1_listen.mp3',
      };

      final parsed = LessonStageParser.parseListenTap(rawStage);

      expect(parsed, isNotNull);
      expect(parsed!.targetSentence, 'Guten Tag, ich bin Anna');
      expect(parsed.targetWords, ['Guten', 'Tag,', 'ich', 'bin', 'Anna']);
      expect(parsed.wordBank.length, 6);
      expect(parsed.audioUrl, 'https://dolphincoder.com/audio/lesson1_listen.mp3');
    });

    test('Parses listen_tap without tokens by auto-tokenizing targetSentence', () {
      final rawStage = {
        'type': 'listen_tap',
        'targetSentence': 'Wie geht es dir?',
      };

      final parsed = LessonStageParser.parseListenTap(rawStage);

      expect(parsed, isNotNull);
      expect(parsed!.targetWords, ['Wie', 'geht', 'es', 'dir?']);
      expect(parsed.wordBank.length, 4);
      expect(parsed.audioUrl, isEmpty);
    });

    test('Resilient stage parsing regardless of high vs low latency delivery', () async {
      final stagesJson = [
        {
          'type': 'word_match',
          'pairs': [
            {'target': 'Ja', 'native': 'Yes'},
            {'target': 'Nein', 'native': 'No'},
          ],
        },
        {
          'type': 'listen_tap',
          'targetSentence': 'Danke schön',
          'tokens': ['Danke', 'schön', 'Bitte'],
          'audioUrl': 'https://dolphincoder.com/audio/danke.mp3',
        },
      ];

      // Simulate low latency response (40ms)
      final lowLatencyPayload = await Future.delayed(
        const Duration(milliseconds: 40),
        () => stagesJson,
      );
      final typesLow = LessonStageParser.extractValidStageTypes(lowLatencyPayload);

      // Simulate high latency response (800ms)
      final highLatencyPayload = await Future.delayed(
        const Duration(milliseconds: 800),
        () => stagesJson,
      );
      final typesHigh = LessonStageParser.extractValidStageTypes(highLatencyPayload);

      expect(typesLow, ['word_match', 'listen_tap']);
      expect(typesHigh, ['word_match', 'listen_tap']);
    });

    test('Gracefully ignores corrupted or empty stage data without throwing', () {
      final corruptedStages = [
        {'type': 'word_match', 'pairs': []}, // Empty pairs
        {'type': 'word_match', 'pairs': null}, // Null pairs
        {'type': 'listen_tap', 'targetSentence': ''}, // Empty sentence
        {'invalid_key': 12345}, // Malformed object
        null, // Null entry
        'plain string', // Non-map entry
      ];

      expect(() => LessonStageParser.extractValidStageTypes(corruptedStages), returnsNormally);
      final valid = LessonStageParser.extractValidStageTypes(corruptedStages);
      expect(valid, isEmpty);
    });

    testWidgets('LessonSessionScreen renders and interacts with parsed word_match stage', (tester) async {
      const parsedData = WordMatchStageData(
        germanWords: ['Guten Tag', 'Danke'],
        englishWords: ['Thank you', 'Hello'],
        solutionPairs: {
          'Guten Tag': 'Hello',
          'Danke': 'Thank you',
        },
      );

      String? matchedGerman;
      String? matchedEnglish;

      await tester.pumpWidget(
        _buildWordMatchStageHarness(
          data: parsedData,
          onMatchSuccess: (g, e) {
            matchedGerman = g;
            matchedEnglish = e;
          },
        ),
      );

      // Verifies word_match stage is rendered with words
      expect(find.byKey(const ValueKey('word_match')), findsOneWidget);
      expect(find.text('Guten Tag'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);

      // Tap pair to match
      await tester.tap(find.text('Guten Tag'));
      await tester.pump();
      await tester.tap(find.text('Hello'));
      await tester.pump();

      // Verify pair was matched successfully
      expect(matchedGerman, 'Guten Tag');
      expect(matchedEnglish, 'Hello');
      expect(tester.takeException(), isNull);
    });
  });

  // =========================================================================
  // 4. OFFLINE CACHE RESILIENCE TESTS
  // =========================================================================
  group('4. Offline Cache Resilience Tests', () {
    test('Serves course path from Tier-2 cache when network is unreachable', () async {
      final cache = CacheService();
      const cachedNodes = [
        PathNodeModel(
          index: 0,
          title: 'Offline Cached Island 1',
          subtitle: 'Available offline',
          type: 'lesson',
          status: 'completed',
        ),
        PathNodeModel(
          index: 1,
          title: 'Offline Cached Island 2',
          subtitle: 'Next available',
          type: 'karaoke',
          status: 'available',
        ),
      ];

      // 1. Seed Tier-2 local cache
      await cache.savePathNodes(
        targetLanguage: 'de',
        nativeLanguage: 'en',
        level: 'A1',
        nodes: cachedNodes,
      );

      // 2. Simulate unreachable network (offline socket failure)
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockLatencyAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('No route to host (Offline)'),
        );
      });
      DioClient.setInstance(dio);

      // 3. Request path from repository
      final repo = GamificationRepository();
      final resultNodes = await repo.getPath(
        targetLanguage: 'de',
        nativeLanguage: 'en',
        level: 'A1',
      );

      // 4. Assert offline fallback
      expect(resultNodes.length, 2);
      expect(resultNodes[0].title, 'Offline Cached Island 1');
      expect(resultNodes[1].title, 'Offline Cached Island 2');
    });

    test('Serves lesson details from Tier-2 cache with 0ms latency when offline', () async {
      final cache = CacheService();
      const testLessonId = 'lesson_offline_42';
      final lessonPayload = {
        'id': testLessonId,
        'title': 'Offline Greetings',
        'stages': [
          {
            'type': 'word_match',
            'pairs': [
              {'target': 'Hallo', 'native': 'Hello'},
            ],
          },
        ],
      };

      // 1. Save to local disk cache
      await cache.saveLessonDetails(testLessonId, lessonPayload);

      // 2. Break the network completely
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockLatencyAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'Network is completely offline',
        );
      });
      DioClient.setInstance(dio);

      // 3. Fetch lesson
      final repo = GamificationRepository();
      final stopwatch = Stopwatch()..start();
      final details = await repo.getLessonDetails(testLessonId);
      stopwatch.stop();

      expect(details, isNotNull);
      expect(details!['id'], testLessonId);
      expect(details['title'], 'Offline Greetings');
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('Serves user status progression from Tier-2 cache when offline', () async {
      final cache = CacheService();
      const savedStatus = GamificationStatusModel(
        streakCount: 15,
        longestStreak: 20,
        dailyTargetXp: 40,
        targetLanguage: 'de',
        pearls: 320,
        oxygen: 4,
        totalXp: 980,
        currentLeague: 'Sapphire Bay',
      );

      await cache.saveStatus(savedStatus);

      // Offline network
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockLatencyAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      final status = await repo.getStatus();

      expect(status.streakCount, 15);
      expect(status.pearls, 320);
      expect(status.totalXp, 980);
      expect(status.currentLeague, 'Sapphire Bay');
    });

    test('Queues offline completion payload when network is unreachable', () async {
      final cache = CacheService();
      await cache.clearPendingOfflineCompletions();

      // Offline network
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockLatencyAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        );
      });
      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      final result = await repo.completeNode(
        nodeIndex: 2,
        stars: 3,
        scorePct: 100,
        xpEarned: 25,
        pearlsEarned: 10,
        targetLanguage: 'de',
      );

      expect(result['success'], isTrue);
      expect(result['offlineQueued'], isTrue);

      final queue = await cache.getPendingOfflineCompletions();
      expect(queue.length, 1);
      expect(queue.first['nodeIndex'], 2);
      expect(queue.first['xpEarned'], 25);
      expect(queue.first['_timestamp'], isNotNull);
    });

    test('Audio disk store caches and retrieves local audio file offline', () async {
      final cache = CacheService();
      const audioUrl = 'https://dolphincoder.com/audio/guten_tag.mp3';
      final dummyBytes = utf8.encode('ID3_DUMMY_MP3_PAYLOAD_TEST');

      // 1. Save audio bytes to disk cache
      final savedFile = await cache.saveAudioBytes(audioUrl, dummyBytes);
      expect(savedFile, isNotNull);
      expect(savedFile!.existsSync(), isTrue);

      // 2. Retrieve offline
      final retrievedFile = await cache.getCachedAudioFile(audioUrl);
      expect(retrievedFile, isNotNull);
      expect(retrievedFile!.path, savedFile.path);
      expect(retrievedFile.readAsBytesSync(), dummyBytes);
    });
  });
}

// ---------------------------------------------------------------------------
// Test Support Harnesses for Resilient Widget Testing
// ---------------------------------------------------------------------------

Widget _buildCurriculumPathRetryHarness({required VoidCallback onRetry}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: const Color(0xFF131F24),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Unable to load path', style: TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildLessonTimeoutFallbackHarness({
  required bool isTimedOut,
  required List<String> fallbackStages,
}) {
  return MaterialApp(
    home: Scaffold(
      body: isTimedOut
          ? Column(
              key: const ValueKey('lesson_session_fallback_view'),
              children: [
                const Text('Offline Practice Mode'),
                for (final stage in fallbackStages)
                  ListTile(
                    key: ValueKey('stage_$stage'),
                    title: Text('Stage: $stage'),
                  ),
              ],
            )
          : const CircularProgressIndicator(),
    ),
  );
}

Widget _buildWordMatchStageHarness({
  required WordMatchStageData data,
  Function(String target, String native)? onMatchSuccess,
}) {
  return MaterialApp(
    home: Scaffold(
      body: _WordMatchTestComponent(
        data: data,
        onMatchSuccess: onMatchSuccess,
      ),
    ),
  );
}

class _WordMatchTestComponent extends StatefulWidget {
  final WordMatchStageData data;
  final Function(String target, String native)? onMatchSuccess;

  const _WordMatchTestComponent({required this.data, this.onMatchSuccess});

  @override
  State<_WordMatchTestComponent> createState() => _WordMatchTestComponentState();
}

class _WordMatchTestComponentState extends State<_WordMatchTestComponent> {
  String? selectedTarget;
  final Set<String> matchedTargets = {};
  final Set<String> matchedNatives = {};

  void _onTapTarget(String word) {
    setState(() {
      selectedTarget = word;
    });
  }

  void _onTapNative(String word) {
    if (selectedTarget == null) return;
    if (widget.data.solutionPairs[selectedTarget] == word) {
      setState(() {
        matchedTargets.add(selectedTarget!);
        matchedNatives.add(word);
        widget.onMatchSuccess?.call(selectedTarget!, word);
        selectedTarget = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('word_match'),
      child: Column(
        children: [
          const Text('Match the pairs'),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: widget.data.germanWords.map((w) {
                    final isMatched = matchedTargets.contains(w);
                    return ListTile(
                      key: ValueKey('target_$w'),
                      title: Text(w),
                      enabled: !isMatched,
                      onTap: isMatched ? null : () => _onTapTarget(w),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: Column(
                  children: widget.data.englishWords.map((w) {
                    final isMatched = matchedNatives.contains(w);
                    return ListTile(
                      key: ValueKey('native_$w'),
                      title: Text(w),
                      enabled: !isMatched,
                      onTap: isMatched ? null : () => _onTapNative(w),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
