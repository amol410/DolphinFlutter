import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dolphincoder/core/constants/api_constants.dart';
import 'package:dolphincoder/core/network/dio_client.dart';
import 'package:dolphincoder/core/services/cache_service.dart';
import 'package:dolphincoder/core/services/prefetch_service.dart';
import 'package:dolphincoder/core/services/speech_lifecycle_bridge.dart';
import 'package:dolphincoder/core/services/speech_recognition_service.dart';
import 'package:dolphincoder/core/services/tts_service.dart';
import 'package:dolphincoder/features/gamification/data/gamification_repository.dart';
import 'package:dolphincoder/features/gamification/providers/gamification_provider.dart';

/// Controlled Mock HTTP Adapter to simulate online responses, network timeouts, and offline failures.
class MockResilienceAdapter implements HttpClientAdapter {
  Future<ResponseBody> Function(RequestOptions options) onFetch;

  MockResilienceAdapter(this.onFetch);

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

/// Dedicated Mock AudioPlayer tracking lifecycle operations.
class MockResilienceAudioPlayer extends AudioPlayer {
  bool pauseCalled = false;
  bool stopCalled = false;

  @override
  Future<void> pause() async {
    pauseCalled = true;
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
  }

  @override
  Future<void> dispose() async {
    // Safely no-op in tests to avoid LateInitializationError on uninitialized _eventStreamSubscription
  }
}

/// Dedicated Lesson Audio Subsystem mirroring DolphinCoder audio streaming & smart TTS fallback logic.
class LessonAudioSubsystem {
  final AudioPlayer audioPlayer;
  final TtsService tts;
  bool isPlayingAudio = false;
  bool simulateStreamFailure = false;

  LessonAudioSubsystem({required this.audioPlayer, required this.tts});

  Future<void> playLessonAudio({
    required String remoteUrl,
    required String fallbackSentence,
    double speed = 1.0,
    Duration timeout = const Duration(seconds: 4),
  }) async {
    if (remoteUrl.isNotEmpty) {
      try {
        if (simulateStreamFailure) {
          throw const SocketException('Connection reset by peer: audio stream failed');
        }
        final cached = await CacheService().getCachedAudioFile(remoteUrl);
        await audioPlayer.stop();
        await audioPlayer.setPlaybackRate(speed);
        if (cached != null) {
          await audioPlayer.play(DeviceFileSource(cached.path));
        } else {
          await audioPlayer.play(UrlSource(remoteUrl)).timeout(timeout);
          PrefetchService().prefetchAudioUrl(remoteUrl);
        }
        isPlayingAudio = true;
        return;
      } catch (e) {
        debugPrint('⚠️ [LessonAudioSubsystem] Remote audio error: $e, falling back to TTS');
      }
    }

    if (fallbackSentence.isNotEmpty) {
      isPlayingAudio = true;
      await tts.speakSentence(fallbackSentence, rate: speed);
      isPlayingAudio = false;
    }
  }

  void pause() {
    audioPlayer.pause();
    tts.stop();
    isPlayingAudio = false;
  }
}

/// Interactive Widget Component for testing widget-level audio fallback behavior.
class LessonAudioTestWidget extends StatefulWidget {
  final LessonAudioSubsystem audioSubsystem;
  final String audioUrl;
  final String sentence;

  const LessonAudioTestWidget({
    super.key,
    required this.audioSubsystem,
    required this.audioUrl,
    required this.sentence,
  });

  @override
  State<LessonAudioTestWidget> createState() => _LessonAudioTestWidgetState();
}

class _LessonAudioTestWidgetState extends State<LessonAudioTestWidget> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const ValueKey('lesson_audio_speaker_button'),
            onPressed: () async {
              await widget.audioSubsystem.playLessonAudio(
                remoteUrl: widget.audioUrl,
                fallbackSentence: widget.sentence,
                timeout: const Duration(milliseconds: 200),
              );
              if (mounted) setState(() {});
            },
            child: const Text('Play Speaker Audio'),
          ),
        ),
      ),
    );
  }
}

/// Interactive Widget Component for testing AppLifecycle interruption (paused, inactive, resumed).
class LessonSessionLifecycleHarness extends StatefulWidget {
  final AudioPlayer audioPlayer;
  final TtsService tts;
  final VoidCallback? onTtsStop;
  final VoidCallback? onPauseHandled;
  final VoidCallback? onResumeHandled;

  const LessonSessionLifecycleHarness({
    super.key,
    required this.audioPlayer,
    required this.tts,
    this.onTtsStop,
    this.onPauseHandled,
    this.onResumeHandled,
  });

  @override
  State<LessonSessionLifecycleHarness> createState() => LessonSessionLifecycleHarnessState();
}

class LessonSessionLifecycleHarnessState extends State<LessonSessionLifecycleHarness>
    with WidgetsBindingObserver {
  bool isAudioPlaying = false;
  bool isSpeechRecording = false;
  Timer? autoPlayTimer;
  Timer? silenceTimer;
  Timer? highlightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Start active timers
    autoPlayTimer = Timer(const Duration(seconds: 10), () {});
    silenceTimer = Timer(const Duration(seconds: 5), () {});
    highlightTimer = Timer(const Duration(seconds: 8), () {});
    isSpeechRecording = true;
    isAudioPlaying = true;
  }

  Future<void> handleLifecycleInterruption(AppLifecycleState state) async {
    didChangeAppLifecycleState(state);
    await widget.audioPlayer.pause();
    await widget.tts.stop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // 1. Safely pause all active audio
      widget.audioPlayer.pause();
      widget.tts.stop();
      widget.onTtsStop?.call();
      isAudioPlaying = false;

      // 2. Safely cancel all active timers
      autoPlayTimer?.cancel();
      autoPlayTimer = null;
      silenceTimer?.cancel();
      silenceTimer = null;
      highlightTimer?.cancel();
      highlightTimer = null;

      // 3. Safely release speech recording
      isSpeechRecording = false;
      SpeechLifecycleBridge.destroyNativeRecognizer();

      if (mounted) setState(() {});

      widget.onPauseHandled?.call();
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() {});
      widget.onResumeHandled?.call();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    autoPlayTimer?.cancel();
    silenceTimer?.cancel();
    highlightTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                isAudioPlaying ? 'Audio Playing' : 'Audio Paused',
                key: const ValueKey('audio_status_text'),
              ),
              Text(
                isSpeechRecording ? 'Speech Recording Active' : 'Speech Idle',
                key: const ValueKey('speech_status_text'),
              ),
              Text(
                autoPlayTimer != null && autoPlayTimer!.isActive ? 'Timers Running' : 'Timers Cancelled',
                key: const ValueKey('timers_status_text'),
              ),
              ElevatedButton(
                key: const ValueKey('test_interactive_btn'),
                onPressed: () {},
                child: const Text('Interact'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempTestDir;
  final List<MethodCall> audioPlayerCalls = [];
  final List<MethodCall> ttsCalls = [];
  final List<MethodCall> bridgeCalls = [];

  bool simulateAudioPlayError = false;
  bool simulateAudioPlayTimeout = false;

  setUpAll(() {
    const channelAudioGlobal = MethodChannel('xyz.luan/audioplayers.global');
    const channelAudio = MethodChannel('xyz.luan/audioplayers');
    const channelPath = MethodChannel('plugins.flutter.io/path_provider');
    const channelTts = MethodChannel('flutter_tts');
    const channelBridge = MethodChannel('com.dolphincoder.lms/speech_lifecycle');
    const channelStt = MethodChannel('plugin.csd.speech_to_text');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelAudioGlobal, (MethodCall call) async => 1);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelAudio, (MethodCall call) async {
      audioPlayerCalls.add(call);
      if (call.method == 'play' || call.method == 'setSourceUrl' || call.method == 'resume') {
        if (simulateAudioPlayError) {
          throw PlatformException(
            code: 'MEDIA_NETWORK_ERROR',
            message: 'Failed to stream audio file: connection refused (503)',
          );
        }
        if (simulateAudioPlayTimeout) {
          await Future.delayed(const Duration(seconds: 10));
          return 1;
        }
      }
      return 1;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelPath, (MethodCall call) async => tempTestDir.path);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelTts, (MethodCall call) async {
      ttsCalls.add(call);
      if (call.method == 'getVoices') {
        return [
          {'name': 'en-us-x-iom-local', 'locale': 'en-US', 'features': '[male]'},
          {'name': 'de-de-x-deb-local', 'locale': 'de-DE', 'features': '[female]'},
        ];
      }
      return 1;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelBridge, (MethodCall call) async {
      bridgeCalls.add(call);
      if (call.method == 'ensureOptimalSpeechEngine') {
        return {
          'isAvailable': true,
          'tier': 'tier1_google',
          'packageName': 'com.google.android.googlequicksearchbox',
          'serviceName': '',
          'injected': false,
        };
      }
      return true;
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelStt, (MethodCall call) async => true);
  });

  setUp(() async {
    audioPlayerCalls.clear();
    ttsCalls.clear();
    bridgeCalls.clear();
    simulateAudioPlayError = false;
    simulateAudioPlayTimeout = false;

    SharedPreferences.setMockInitialValues({});
    tempTestDir = Directory.systemTemp.createTempSync('dolphin_resilience_test_');

    final cache = CacheService();
    cache.reset();
    await cache.setActiveUser('test_resilience_user');
    cache.setAudioCacheDir(tempTestDir);

    DioClient.reset();
  });

  tearDown(() async {
    await TtsService().stop();
    try {
      if (tempTestDir.existsSync()) {
        tempTestDir.deleteSync(recursive: true);
      }
    } catch (_) {}
    DioClient.reset();
    CacheService().reset();
  });

  // =========================================================================
  // 1. AUDIO STREAMING NETWORK FAILURE FALLBACK TESTS
  // =========================================================================
  group('1. Audio Streaming Network Failure Fallback', () {
    test('Remote audio stream failure triggers on-device TTS fallback without unhandled exception', () async {
      simulateAudioPlayError = true;
      final tts = TtsService();
      await tts.setLanguage('de');

      const targetSentence = 'Guten Tag, wie geht es dir?';
      const remoteAudioUrl = 'https://dolphincoder.com/audio/not_found_sample.mp3';

      final testAudioPlayer = AudioPlayer();
      final subsystem = LessonAudioSubsystem(audioPlayer: testAudioPlayer, tts: tts)
        ..simulateStreamFailure = true;

      // Play remote audio with failure simulation
      await expectLater(
        subsystem.playLessonAudio(
          remoteUrl: remoteAudioUrl,
          fallbackSentence: targetSentence,
        ),
        completes,
      );

      // Verify TTS speak was triggered with target sentence
      final speakCalls = ttsCalls.where((c) => c.method == 'speak').toList();
      expect(speakCalls, isNotEmpty, reason: 'TTS fallback must be called when remote audio stream fails');
      expect(speakCalls.last.arguments, targetSentence);

      testAudioPlayer.dispose();
    });

    test('Remote audio streaming network timeout triggers TTS fallback within timeout limit', () async {
      simulateAudioPlayTimeout = true;
      final tts = TtsService();
      await tts.setLanguage('en');

      const targetSentence = 'Welcome back to dolphin learning.';
      const remoteAudioUrl = 'https://dolphincoder.com/audio/stalled_stream.mp3';

      final testAudioPlayer = AudioPlayer();
      final subsystem = LessonAudioSubsystem(audioPlayer: testAudioPlayer, tts: tts);

      final stopwatch = Stopwatch()..start();
      // Enforce 1-second test timeout (production uses 4-second timeout)
      await subsystem.playLessonAudio(
        remoteUrl: remoteAudioUrl,
        fallbackSentence: targetSentence,
        timeout: const Duration(seconds: 1),
      );
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(3500),
          reason: 'Audio stream timeout must abort promptly without app freeze');

      final speakCalls = ttsCalls.where((c) => c.method == 'speak').toList();
      expect(speakCalls, isNotEmpty);
      expect(speakCalls.last.arguments, targetSentence);

      testAudioPlayer.dispose();
    });

    test('TtsService.speakWord falls back to native TTS when low-latency cached audio playback fails', () async {
      final tts = TtsService();
      await tts.setLanguage('de');

      // Pre-create a dummy file on disk to simulate a corrupted audio cache entry
      final fileName = tts.getFileNameForWordForTesting('Wasser', 'de-DE');
      final corruptedFile = File('${tempTestDir.path}/$fileName');
      await corruptedFile.create(recursive: true);
      await corruptedFile.writeAsString('corrupted dummy audio content');

      // Simulate player error on play
      simulateAudioPlayError = true;

      // Invoke speakWord - catches low-latency failure and falls back to native TTS
      await expectLater(tts.speakWord('Wasser'), completes);

      // Verify native flutterTts.speak was invoked as fallback
      final speakCalls = ttsCalls.where((c) => c.method == 'speak').toList();
      expect(speakCalls, isNotEmpty);
      expect(speakCalls.last.arguments, 'Wasser');
    });

    test('PrefetchService handles remote audio download timeouts without crashing or blocking queue', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockResilienceAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
          message: 'Connection timed out while downloading audio',
        );
      });
      DioClient.setInstance(dio);

      final prefetch = PrefetchService();
      const testAudioUrl = 'https://dolphincoder.com/audio/test_timeout_clip.mp3';

      // Prefetching a failing URL must complete normally without unhandled exceptions
      await expectLater(prefetch.prefetchAudioUrl(testAudioUrl), completes);

      // Verify file was not written to disk
      final cached = await CacheService().getCachedAudioFile(testAudioUrl);
      expect(cached, isNull);

      // Verify subsequent request can still be dispatched (lock was released)
      await expectLater(prefetch.prefetchAudioUrl(testAudioUrl), completes);
    });

    test('Interactive audio component triggers on-device TTS fallback upon streaming failure', () async {
      final tts = TtsService();
      await tts.setLanguage('de');

      final testAudioPlayer = MockResilienceAudioPlayer();
      final subsystem = LessonAudioSubsystem(audioPlayer: testAudioPlayer, tts: tts)
        ..simulateStreamFailure = true;

      // Trigger audio playback with simulated stream failure
      await subsystem.playLessonAudio(
        remoteUrl: 'https://dolphincoder.com/audio/failing_network_track.mp3',
        fallbackSentence: 'Guten Morgen, Anna',
      );

      // Verify TTS was invoked as fallback
      final speakCalls = ttsCalls.where((c) => c.method == 'speak').toList();
      expect(speakCalls, isNotEmpty);
      expect(speakCalls.last.arguments, 'Guten Morgen, Anna');
      expect(subsystem.isPlayingAudio, isFalse, reason: 'Playback state resets safely after fallback completion');

      testAudioPlayer.dispose();
    });
  });

  // =========================================================================
  // 2. APP LIFECYCLE INTERRUPTION TESTS
  // =========================================================================
  group('2. App Lifecycle Interruption', () {
    testWidgets('AppLifecycleState.paused safely pauses audio, cancels timers, and releases speech recording', (tester) async {
      final testAudioPlayer = MockResilienceAudioPlayer();
      final tts = TtsService();
      bool pauseCallbackFired = false;
      bool ttsStopCalled = false;
      final harnessKey = GlobalKey<LessonSessionLifecycleHarnessState>();

      await tester.pumpWidget(
        LessonSessionLifecycleHarness(
          key: harnessKey,
          audioPlayer: testAudioPlayer,
          tts: tts,
          onTtsStop: () {
            ttsStopCalled = true;
          },
          onPauseHandled: () {
            pauseCallbackFired = true;
          },
        ),
      );

      await tester.pumpAndSettle();

      // Verify initial active state
      expect(find.text('Audio Playing'), findsOneWidget);
      expect(find.text('Speech Recording Active'), findsOneWidget);
      expect(find.text('Timers Running'), findsOneWidget);

      // Simulate incoming call / app backgrounding: system transitions to paused
      harnessKey.currentState!.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      // Verify audio paused, timers cancelled, speech recording released
      expect(pauseCallbackFired, isTrue);
      expect(find.text('Audio Paused'), findsOneWidget);
      expect(find.text('Speech Idle'), findsOneWidget);
      expect(find.text('Timers Cancelled'), findsOneWidget);

      // Verify audio player pause and tts stop method calls were invoked
      expect(testAudioPlayer.pauseCalled, isTrue);
      expect(ttsStopCalled, isTrue);

      expect(tester.takeException(), isNull);
      testAudioPlayer.dispose();
    });

    testWidgets('AppLifecycleState.inactive safely handles interruption without crashing', (tester) async {
      final testAudioPlayer = MockResilienceAudioPlayer();
      final tts = TtsService();
      bool ttsStopCalled = false;
      final harnessKey = GlobalKey<LessonSessionLifecycleHarnessState>();

      await tester.pumpWidget(
        LessonSessionLifecycleHarness(
          key: harnessKey,
          audioPlayer: testAudioPlayer,
          tts: tts,
          onTtsStop: () {
            ttsStopCalled = true;
          },
        ),
      );

      await tester.pumpAndSettle();

      // Transition to inactive (e.g. notification shade or app switcher opened)
      harnessKey.currentState!.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      expect(testAudioPlayer.pauseCalled, isTrue);
      expect(ttsStopCalled, isTrue);
      expect(find.text('Audio Paused'), findsOneWidget);
      expect(find.text('Timers Cancelled'), findsOneWidget);
      expect(tester.takeException(), isNull);

      testAudioPlayer.dispose();
    });

    testWidgets('App resumes safely from paused state without crash or state corruption', (tester) async {
      final testAudioPlayer = MockResilienceAudioPlayer();
      final tts = TtsService();
      bool resumeCallbackFired = false;
      final harnessKey = GlobalKey<LessonSessionLifecycleHarnessState>();

      await tester.pumpWidget(
        LessonSessionLifecycleHarness(
          key: harnessKey,
          audioPlayer: testAudioPlayer,
          tts: tts,
          onResumeHandled: () {
            resumeCallbackFired = true;
          },
        ),
      );

      await tester.pumpAndSettle();

      // 1. App goes to background
      harnessKey.currentState!.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pumpAndSettle();

      // 2. User returns: app resumes
      harnessKey.currentState!.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(resumeCallbackFired, isTrue);

      // 3. App remains fully interactive without crashing
      await tester.tap(find.byKey(const ValueKey('test_interactive_btn')));
      await tester.pump();

      expect(tester.takeException(), isNull);
      testAudioPlayer.dispose();
    });

    test('SpeechLifecycleBridge routes onAudioFocusLost to registered listeners and releases audio', () async {
      int audioFocusLostCount = 0;

      final unsubscribe = SpeechLifecycleBridge.subscribeAudioLifecycle(
        onAudioFocusLost: () {
          audioFocusLostCount++;
        },
      );

      // Simulate native Android audio focus loss callback (e.g., incoming call / alarm)
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'com.dolphincoder.lms/speech_lifecycle',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onAudioFocusLost')),
        (ByteData? data) {},
      );

      expect(audioFocusLostCount, 1);
      unsubscribe();
    });

    test('SpeechLifecycleBridge routes onAudioBecomingNoisy when headphones are disconnected', () async {
      int noisyCount = 0;

      final unsubscribe = SpeechLifecycleBridge.subscribeAudioLifecycle(
        onAudioBecomingNoisy: () {
          noisyCount++;
        },
      );

      // Simulate native Android ACTION_AUDIO_BECOMING_NOISY broadcast
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'com.dolphincoder.lms/speech_lifecycle',
        const StandardMethodCodec().encodeMethodCall(const MethodCall('onAudioBecomingNoisy')),
        (ByteData? data) {},
      );

      expect(noisyCount, 1);
      unsubscribe();
    });

    test('SpeechRecognitionService.cancelListening safely releases resources and resets state to idle', () async {
      final sttService = SpeechRecognitionService();

      // Cancel listening when idle or active must complete safely
      await expectLater(sttService.cancelListening(), completes);

      // Verifies state safely resets to idle
      expect(sttService.state, SpeechServiceState.idle);
    });
  });

  // =========================================================================
  // 3. OFFLINE LESSON COMPLETION QUEUEING TESTS
  // =========================================================================
  group('3. Offline Lesson Completion Queueing', () {
    test('Serializes completion record into local cache when network is unavailable', () async {
      final cache = CacheService();
      await cache.clearPendingOfflineCompletions();

      // Simulate network socket disconnection
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockResilienceAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('Network connection unavailable (Offline)'),
        );
      });
      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      const testNodeIndex = 3;
      const testScorePct = 95;

      final result = await repo.completeNode(
        nodeIndex: testNodeIndex,
        scorePct: testScorePct,
        targetLanguage: 'de',
        nativeLanguage: 'en',
        level: 'A1',
      );

      // Verify return value indicates offline queueing
      expect(result['success'], isFalse);
      expect(result['offlineQueued'], isTrue);
      expect(result['attemptId'], isNotNull);

      final attemptId = result['attemptId'] as String;

      // Verify completion record was serialized and saved to Tier-2 local cache
      final pendingQueue = await cache.getPendingOfflineCompletions();
      expect(pendingQueue, isNotEmpty);
      expect(pendingQueue.length, 1);

      final record = pendingQueue.first;
      expect(record['nodeIndex'], testNodeIndex);
      expect(record['scorePct'], testScorePct);
      expect(record['targetLanguage'], 'de');
      expect(record['nativeLanguage'], 'en');
      expect(record['level'], 'A1');
      expect(record['attemptId'], attemptId);
      expect(record['_timestamp'], isNotNull);
    });

    test('Queues multiple offline completions sequentially without data loss', () async {
      final cache = CacheService();
      await cache.clearPendingOfflineCompletions();

      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockResilienceAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'Offline',
        );
      });
      DioClient.setInstance(dio);

      final repo = GamificationRepository();

      // Complete 3 different nodes while offline
      final res1 = await repo.completeNode(nodeIndex: 0, scorePct: 100);
      final res2 = await repo.completeNode(nodeIndex: 1, scorePct: 88);
      final res3 = await repo.completeNode(nodeIndex: 2, scorePct: 92);

      expect(res1['offlineQueued'], isTrue);
      expect(res2['offlineQueued'], isTrue);
      expect(res3['offlineQueued'], isTrue);

      final queue = await cache.getPendingOfflineCompletions();
      expect(queue.length, 3);
      expect(queue[0]['nodeIndex'], 0);
      expect(queue[1]['nodeIndex'], 1);
      expect(queue[2]['nodeIndex'], 2);
      expect(queue[0]['scorePct'], 100);
      expect(queue[1]['scorePct'], 88);
      expect(queue[2]['scorePct'], 92);

      // Verify each item has a unique attempt ID
      final attemptIds = queue.map((item) => item['attemptId']).toSet();
      expect(attemptIds.length, 3);
    });

    test('Replays queued offline completions and prunes them from cache upon reconnection', () async {
      final cache = CacheService();
      await cache.clearPendingOfflineCompletions();

      // 1. Seed 2 offline completions into cache
      const payload1 = {
        'nodeIndex': 4,
        'scorePct': 100,
        'attemptId': 'offline_att_001',
      };
      const payload2 = {
        'nodeIndex': 5,
        'scorePct': 90,
        'attemptId': 'offline_att_002',
      };
      await cache.queueOfflineCompletion(payload1);
      await cache.queueOfflineCompletion(payload2);

      final queuedBefore = await cache.getPendingOfflineCompletions();
      expect(queuedBefore.length, 2);

      // 2. Restore network connectivity (Dio returns 200 OK with success: true)
      final replayedPayloads = <Map<String, dynamic>>[];
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockResilienceAdapter((options) async {
        if (options.path.contains(ApiConstants.gamificationCompleteNode)) {
          if (options.data is Map<String, dynamic>) {
            replayedPayloads.add(options.data as Map<String, dynamic>);
          }
          final body = jsonEncode({
            'success': true,
            'stars': 3,
            'xpEarned': 15,
            'message': 'Node completed successfully',
          });
          return ResponseBody.fromString(body, 200, headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          });
        }
        return ResponseBody.fromString('{"success": true}', 200);
      });
      DioClient.setInstance(dio);

      // 3. Trigger synchronization replay
      final repo = GamificationRepository();
      await repo.replayOfflineCompletions();

      // 4. Verify both items were dispatched to the server
      expect(replayedPayloads.length, 2);
      expect(replayedPayloads[0]['attemptId'], 'offline_att_001');
      expect(replayedPayloads[1]['attemptId'], 'offline_att_002');

      // 5. Verify local cache queue is now clean and empty
      final queuedAfter = await cache.getPendingOfflineCompletions();
      expect(queuedAfter, isEmpty);
    });

    test('Partial replay failure preserves un-synced items safely in queue', () async {
      final cache = CacheService();
      await cache.clearPendingOfflineCompletions();

      await cache.queueOfflineCompletion({
        'nodeIndex': 10,
        'scorePct': 100,
        'attemptId': 'partial_att_1',
      });
      await cache.queueOfflineCompletion({
        'nodeIndex': 11,
        'scorePct': 95,
        'attemptId': 'partial_att_2',
      });

      int postCount = 0;
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockResilienceAdapter((options) async {
        postCount++;
        if (postCount == 1) {
          // First item succeeds
          return ResponseBody.fromString(
            jsonEncode({'success': true, 'stars': 3}),
            200,
            headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
          );
        } else {
          // Network disconnects during second item
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: const SocketException('Connection dropped mid-sync'),
          );
        }
      });
      DioClient.setInstance(dio);

      final repo = GamificationRepository();
      await repo.replayOfflineCompletions();

      // Item 1 was synced and pruned; Item 2 remains queued for next sync
      final remaining = await cache.getPendingOfflineCompletions();
      expect(remaining.length, 1);
      expect(remaining.first['attemptId'], 'partial_att_2');
      expect(remaining.first['nodeIndex'], 11);
    });

    test('User-scoped offline completions maintain isolated queues between different accounts', () async {
      final cache = CacheService();

      // User A
      await cache.setActiveUser('user_alpha');
      await cache.clearPendingOfflineCompletions();
      await cache.queueOfflineCompletion({
        'nodeIndex': 1,
        'scorePct': 100,
        'attemptId': 'user_a_att_1',
      });

      final queueA = await cache.getPendingOfflineCompletions();
      expect(queueA.length, 1);
      expect(queueA.first['attemptId'], 'user_a_att_1');

      // Switch to User B
      await cache.setActiveUser('user_beta');
      await cache.clearPendingOfflineCompletions();

      final queueB = await cache.getPendingOfflineCompletions();
      expect(queueB, isEmpty);

      // Switch back to User A
      await cache.setActiveUser('user_alpha');
      final queueAReturned = await cache.getPendingOfflineCompletions();
      expect(queueAReturned.length, 1);
      expect(queueAReturned.first['attemptId'], 'user_a_att_1');
    });

    test('PathNodesNotifier handles offline lesson completion without error', () async {
      final dio = Dio(BaseOptions(baseUrl: ApiConstants.defaultBaseUrl));
      dio.httpClientAdapter = MockResilienceAdapter((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: 'Offline',
        );
      });
      DioClient.setInstance(dio);

      final container = ProviderContainer();
      final notifier = container.read(pathNodesProvider.notifier);

      final result = await notifier.completeNode(1, scorePct: 90);

      expect(result['offlineQueued'], isTrue);
      expect(result['attemptId'], isNotNull);

      final queue = await CacheService().getPendingOfflineCompletions();
      expect(queue.any((item) => item['nodeIndex'] == 1), isTrue);

      await Future.delayed(const Duration(milliseconds: 100));
      container.dispose();
    });
  });
}
