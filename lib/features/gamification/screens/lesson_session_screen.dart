import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/constants/api_constants.dart';
import '../../../core/services/speech_lifecycle_bridge.dart';
import '../../../shared/widgets/animated_dolphin_mascot.dart';
import '../../../shared/widgets/tactile_game_button.dart';
import '../../../shared/widgets/duo_feedback_sheet.dart';
import '../../../shared/widgets/out_of_oxygen_dialog.dart';
import '../../notes/data/models/karaoke_model.dart';
import '../data/models/gamification_models.dart';
import '../data/lesson_stage_parser.dart';
import '../providers/gamification_provider.dart';
import '../../../core/services/tts_service.dart';
import '../../../core/services/pronunciation_evaluator.dart';
import '../../../core/providers/speech_preferences_provider.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/services/prefetch_service.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/services/sound_effects_service.dart';

/// Interactive Lesson Session Screen
/// Multi-stage interactive tasks based on Basics & Greetings and backend notes.
/// Delivers word matching, listening comprehension, sentence building,
/// and speech pronunciation with dopamine rewards and mascot animations.
class LessonSessionScreen extends ConsumerStatefulWidget {
  final int nodeIndex;
  final PathNodeModel? node;

  const LessonSessionScreen({
    super.key,
    required this.nodeIndex,
    this.node,
  });

  @override
  ConsumerState<LessonSessionScreen> createState() => _LessonSessionScreenState();
}

enum SpeechSessionState {
  idle,
  listening,
  stopping,
  error,
}

class _LessonSessionScreenState extends ConsumerState<LessonSessionScreen>
    with WidgetsBindingObserver {
  int _currentStage = 0;
  List<String> _activeStageTypes = [];
  int get _totalStages => _activeStageTypes.length;
  bool get _isCelebrationStage => _currentStage >= _totalStages;
  bool _currentStageReEnqueued = false;

  // Economy & Accuracy Tracking
  int _initialTotalStages = 0;
  int _mistakesCount = 0;

  int get _calculatedAccuracy {
    final baseCount = _initialTotalStages > 0 ? _initialTotalStages : (_totalStages > 0 ? _totalStages : 1);
    final totalAttempts = baseCount + _mistakesCount;
    if (totalAttempts <= 0 || _mistakesCount == 0) return 100;
    final pct = ((baseCount / totalAttempts) * 100).round();
    return pct.clamp(0, 100);
  }

  int get _earnedXp {
    const baseXp = 10;
    final acc = _calculatedAccuracy;
    final bonus = acc == 100 ? 2 : (acc >= 80 ? 1 : 0);
    return baseXp + bonus;
  }

  int get _earnedPearls {
    return _calculatedAccuracy == 100 ? 1 : 0;
  }

  // Rewarded Ad Bonus XP state
  bool _hasClaimedDoubleXp = false;
  bool _isLoadingDoubleXpAd = false;

  late final AudioPlayer _audioPlayer;
  StreamSubscription? _playerCompleteSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;

  bool _isPlayingAudio = false;
  String _preparedAudioUrl = '';
  bool _isLoadingLessonDetails = false;

  // ── Stage 0: Word Match Data ──────────────────────────────────────
  List<String> _germanWords = ['Guten Tag', 'Danke', 'Bitte', 'Tschüss'];
  List<String> _englishWords = ['Thank you', 'Bye', 'Hello', 'Please'];
  Map<String, String> _solutionPairs = {
    'Guten Tag': 'Hello',
    'Danke': 'Thank you',
    'Bitte': 'Please',
    'Tschüss': 'Bye',
  };
  final Set<String> _matchedGerman = {};
  final Set<String> _matchedEnglish = {};
  String? _selectedGerman;
  String? _selectedEnglish;
  String? _wrongGermanWord;
  String? _wrongEnglishWord;
  String? _correctGermanWord;
  String? _correctEnglishWord;
  bool _matchFinished = false;
  bool _isEvaluatingMatch = false;

  // ── Stage 1: Listening Data ───────────────────────────────────────
  String _listenTargetSentence = 'Guten Tag, ich bin Anna';
  List<String> _listenBank = ['Kaffee', 'Guten', 'Tag,', 'ich', 'bin', 'Anna'];
  List<String> _listenTarget = ['Guten', 'Tag,', 'ich', 'bin', 'Anna'];
  final List<int> _listenSelectedIndices = [];
  List<String> get _listenSelected => _listenSelectedIndices.map((i) => _listenBank[i]).toList();
  bool? _listenCorrect;
  String _listenAudioUrl = '';

  // ── Stage 2: Sentence Builder Data ────────────────────────────────
  String _sentencePrompt = 'Translate: "Good morning, how are you?"';
  String _builderTargetSentence = 'Guten Morgen, wie geht es dir?';
  List<String> _builderBank = ['Guten', 'Morgen,', 'wie', 'geht', 'es', 'dir?', 'schlafe', 'Kalt'];
  List<String> _builderTarget = ['Guten', 'Morgen,', 'wie', 'geht', 'es', 'dir?'];
  final List<int> _builderSelectedIndices = [];
  List<String> get _builderSelected => _builderSelectedIndices.map((i) => _builderBank[i]).toList();
  bool? _builderCorrect;

  // ── Stage 3: Sprechen Voice & Lip-Sync Karaoke Data ───────────────
  String _sprechenPrompt = 'Guten Tag! Wie geht es dir?';
  String _sprechenTranslation = 'Hello! How are you?';
  String _sprechenAudioUrl = '';
  List<KaraokeWord> _sprechenKaraokeWords = [];
  int _sprechenMinAccuracy = 75;
  bool _hasPlayedSprechenDemo = false;
  bool _isSprechenDemoPlaying = false;
  Timer? _sprechenAutoPlayTimer;
  Timer? _ttsHighlightTimer;

  stt.SpeechToText? _speech;
  bool _speechInitialized = false;
  SpeechSessionState _speechSessionState = SpeechSessionState.idle;
  bool get _isSpeaking => _speechSessionState == SpeechSessionState.listening;
  DateTime _lastSpeechErrorTime = DateTime.fromMillisecondsSinceEpoch(0);
  bool? _speechPassed;
  String _spokenText = '';
  int _speechAccuracy = 0;
  List<EvaluatedToken> _evaluatedTokens = [];
  Timer? _silenceTimer;

  // ── Stage 4: Cloze Test (Fill in the Blank) ───────────────────────
  String _clozeSentence = 'Ich _____ aus Indien.';
  String _clozeTranslation = 'I come from India.';
  String _clozeBlank = 'komme';
  List<String> _clozeOptions = ['komme', 'kommst', 'wohne'];
  String? _clozeSelectedOption;
  bool? _clozeCorrect;

  // ── Stage 5: Type Word (Target Typing with Umlaut Buttons) ────────
  String _typePrompt = 'Der Kaffee ist _____.';
  String _typeTranslation = 'The coffee is hot.';
  String _typeTarget = 'heiß';
  String _typeHint = 'Translate "hot" into German';
  final TextEditingController _typeWordController = TextEditingController();
  bool? _typeCorrect;

  // ── Stage 6: Dialogue Bubble (Conversational Chat) ────────────────
  String _dialoguePartnerName = 'Florian';
  String _dialoguePartnerMessage = 'Hallo! Wie heißt du?';
  String _dialoguePartnerTranslation = 'Hello! What is your name?';
  List<Map<String, dynamic>> _dialogueOptions = [];
  int? _dialogueSelectedIdx;
  bool? _dialogueCorrect;

  // ── Stage 7: Listen Select (Comprehension MCQ) ────────────────────
  String _listenSelectSentence = 'Zwei Kaffee und ein Wasser, bitte.';
  String _listenSelectQuestion = 'What is the customer ordering?';
  String _listenSelectAudioUrl = '';
  List<Map<String, dynamic>> _listenSelectOptions = [];
  int? _listenSelectSelectedIdx;
  bool? _listenSelectCorrect;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer = AudioPlayer();
    TtsService().warmUp();

    // Register Duolingo-Parity Audio Focus and BECOMING_NOISY Listeners
    SpeechLifecycleBridge.registerAudioLifecycleListeners(
      onAudioBecomingNoisy: () {
        if (!mounted) return;
        debugPrint('🎧 [LessonSessionScreen] Headphones disconnected -> Pausing audio immediately');
        _pauseAllAudio();
      },
      onAudioFocusLost: () {
        if (!mounted) return;
        debugPrint('🔇 [LessonSessionScreen] Audio focus lost (phone call/alarm) -> Pausing audio & releasing speech');
        _pauseAllAudio();
        _forceReleaseSpeechRecognizer();
      },
    );

    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _isSprechenDemoPlaying = false;
        });
      }
    });

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = (state == PlayerState.playing);
          if (state != PlayerState.playing) {
            _isSprechenDemoPlaying = false;
          }
        });
      }
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((pos) {
      if (!mounted) return;
      // Machine reference audio playback remains calm and stationary
    });

    _initStagesData();

    if (!_isLoadingLessonDetails) {
      _startFirstStage();
    }
  }

  void _pauseAllAudio() {
    _audioPlayer.pause();
    TtsService().stop();
    if (mounted) {
      setState(() {
        _isPlayingAudio = false;
        _isSprechenDemoPlaying = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      debugPrint('📱 [LessonSessionScreen] Lifecycle $state -> releasing SpeechRecognizer');
      _forceReleaseSpeechRecognizer();
    }
  }

  Future<void> _forceReleaseSpeechRecognizer() async {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    final speechToRelease = _speech;
    _speech = null;
    _speechInitialized = false;
    if (mounted) {
      setState(() => _speechSessionState = SpeechSessionState.idle);
    } else {
      _speechSessionState = SpeechSessionState.idle;
    }

    if (speechToRelease != null) {
      try {
        await speechToRelease.cancel();
      } catch (e) {
        debugPrint('⚠️ [LessonSessionScreen] Speech cancel note: $e');
      }
    }
    await SpeechLifecycleBridge.destroyNativeRecognizer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _silenceTimer?.cancel();
    _ttsHighlightTimer?.cancel();
    _sprechenAutoPlayTimer?.cancel();
    _playerCompleteSub?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _forceReleaseSpeechRecognizer();
    TtsService().stop();
    _audioPlayer.stop();
    _typeWordController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _resolveAudioUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return '';
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    final clean = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    if (clean.startsWith('/api')) {
      return 'https://dolphincoder.com$clean';
    }
    return '${ApiConstants.defaultBaseUrl}$clean';
  }

  Future<void> _prepareListenAudio() async {
    final rawUrl = _listenAudioUrl.trim();
    final url = _resolveAudioUrl(rawUrl);
    if (url.isEmpty || url == _preparedAudioUrl) return;

    try {
      _preparedAudioUrl = url;
      await _audioPlayer.setSourceUrl(url);
      debugPrint('🎵 [_prepareListenAudio] Pre-warmed audio: $url');
    } catch (e) {
      debugPrint('⚠️ [_prepareListenAudio] Audio pre-warm error: $e');
    }
  }

  Future<void> _playListenAudio({double speed = 1.0}) async {
    final rawUrl = _listenAudioUrl.trim();
    final url = _resolveAudioUrl(rawUrl);

    if (url.isNotEmpty) {
      try {
        if (!mounted) return;
        final cachedFile = await CacheService().getCachedAudioFile(url);
        if (!mounted) return;
        await _audioPlayer.stop();
        if (!mounted) return;
        await _audioPlayer.setPlaybackRate(speed);
        if (!mounted) return;
        if (cachedFile != null) {
          debugPrint('🔊 [_playListenAudio] Playing from Tier-2 disk audio cache: ${cachedFile.path} (speed: $speed)');
          await _audioPlayer.play(DeviceFileSource(cachedFile.path));
        } else {
          debugPrint('🔊 [_playListenAudio] Playing studio audio: $url (speed: $speed)');
          await _audioPlayer.play(UrlSource(url));
          PrefetchService().prefetchAudioUrl(url);
        }
        if (!mounted) return;
        _preparedAudioUrl = url;
        if (mounted) setState(() => _isPlayingAudio = true);
        return;
      } catch (e) {
        debugPrint('⚠️ [_playListenAudio] Audio playback error: $e, falling back to TTS');
      }
    }

    // Smart Hybrid Fallback: Native German TTS for this specific lesson!
    if (_listenTargetSentence.isNotEmpty) {
      debugPrint('🔊 [_playListenAudio] Smart Hybrid TTS speaking: $_listenTargetSentence (speed: $speed)');
      if (!mounted) return;
      if (mounted) setState(() => _isPlayingAudio = true);
      await TtsService().speakSentence(_listenTargetSentence, rate: speed);
      if (!mounted) return;
      if (mounted) setState(() => _isPlayingAudio = false);
    }
  }

  Future<void> _playListenSelectAudio({double speed = 1.0}) async {
    final rawUrl = _listenSelectAudioUrl.trim();
    final url = _resolveAudioUrl(rawUrl);

    if (url.isNotEmpty) {
      try {
        if (!mounted) return;
        final cachedFile = await CacheService().getCachedAudioFile(url);
        if (!mounted) return;
        await _audioPlayer.stop();
        if (!mounted) return;
        await _audioPlayer.setPlaybackRate(speed);
        if (!mounted) return;
        if (cachedFile != null) {
          debugPrint('🔊 [_playListenSelectAudio] Playing from Tier-2 disk audio cache: ${cachedFile.path}');
          await _audioPlayer.play(DeviceFileSource(cachedFile.path));
        } else {
          debugPrint('🔊 [_playListenSelectAudio] Playing studio audio: $url (speed: $speed)');
          await _audioPlayer.play(UrlSource(url));
          PrefetchService().prefetchAudioUrl(url);
        }
        if (!mounted) return;
        if (mounted) setState(() => _isPlayingAudio = true);
        return;
      } catch (e) {
        debugPrint('⚠️ [_playListenSelectAudio] Studio audio failed: $e, falling back to TTS');
      }
    }

    if (_listenSelectSentence.isNotEmpty) {
      debugPrint('🔊 [_playListenSelectAudio] Smart Hybrid TTS speaking: $_listenSelectSentence (speed: $speed)');
      if (!mounted) return;
      if (mounted) setState(() => _isPlayingAudio = true);
      await TtsService().speakSentence(_listenSelectSentence, rate: speed);
      if (!mounted) return;
      if (mounted) setState(() => _isPlayingAudio = false);
    }
  }

  void _startFirstStage() {
    if (_activeStageTypes.isEmpty) return;
    final firstType = _activeStageTypes.first;
    if (firstType == 'listen_tap') {
      _prepareListenAudio();
      Future.delayed(const Duration(milliseconds: 350), () {
        if (mounted && _activeStageTypes.isNotEmpty && _activeStageTypes.first == 'listen_tap') {
          _playListenAudio();
        }
      });
    } else if (firstType == 'sprechen') {
      _triggerSprechenAutoPlay();
    } else if (firstType == 'dialogue_bubble') {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _activeStageTypes.isNotEmpty && _activeStageTypes.first == 'dialogue_bubble') {
          TtsService().speakSentence(_dialoguePartnerMessage);
        }
      });
    } else if (firstType == 'listen_select') {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && _activeStageTypes.isNotEmpty && _activeStageTypes.first == 'listen_select') {
          _playListenSelectAudio();
        }
      });
    }
  }

  void _initStagesData() {
    // Check if pathNodesProvider has a newer copy of this node
    final nodesAsync = ref.read(pathNodesProvider);
    PathNodeModel? activeNode = widget.node;
    if (nodesAsync is AsyncData<List<PathNodeModel>>) {
      final found = nodesAsync.value.where((n) => n.index == widget.nodeIndex).firstOrNull;
      if (found != null) {
        activeNode = found;
      }
    }

    final currentStatus = ref.read(gamificationStatusProvider).value;
    final currentTarget = currentStatus?.targetLanguage ?? 'de';
    TtsService().setLanguage(currentTarget);

    final stages = activeNode?.stages;
    _listenAudioUrl = '';
    _sprechenAudioUrl = '';

    if (stages == null || stages.isEmpty) {
      if (activeNode?.id != null) {
        final lessonId = activeNode!.id;
        // Check Tier-2 cache for instant 0ms launch
        CacheService().getCachedLessonDetails(lessonId).then((cachedData) {
          if (!mounted) return;
          if (cachedData != null &&
              cachedData['stages'] is List &&
              (cachedData['stages'] as List).isNotEmpty) {
            debugPrint('⚡ [_initStagesData] Instant 0ms launch from Tier-2 cache for lesson $lessonId');
            _applyStages(cachedData['stages'] as List);
            setState(() {
              _isLoadingLessonDetails = false;
            });
            _startFirstStage();
            return;
          }
          // If not in cache, fallback to background fetch
          _isLoadingLessonDetails = true;
          _fetchLessonDetails(lessonId);
        });
        return;
      }
      _applyFallbackStages();
      return;
    }

    _applyStages(stages);
  }

  Future<void> _fetchLessonDetails(dynamic lessonId) async {
    try {
      final lessonData = await ref.read(gamificationRepositoryProvider).getLessonDetails(lessonId);
      if (!mounted) return;
      if (lessonData != null && lessonData['stages'] is List && (lessonData['stages'] as List).isNotEmpty) {
        final stages = lessonData['stages'] as List;
        _applyStages(stages);
        if (mounted) {
          setState(() {
            _isLoadingLessonDetails = false;
          });
          _startFirstStage();
        }
        return;
      }
    } catch (e) {
      debugPrint('⚠️ [_fetchLessonDetails] Error fetching details: $e');
    }

    if (mounted) {
      _applyFallbackStages();
      setState(() {
        _isLoadingLessonDetails = false;
      });
      _startFirstStage();
    }
  }

  void _applyFallbackStages() {
    _activeStageTypes = [
      'word_match',
      'listen_tap',
      'cloze_test',
      'sentence_builder',
      'type_word',
      'dialogue_bubble',
      'listen_select',
      'sprechen',
    ];
    if (_initialTotalStages == 0) {
      _initialTotalStages = _activeStageTypes.length;
    }

    final currentTarget = ref.read(gamificationStatusProvider).value?.targetLanguage ?? 'de';
    final isEnglish = currentTarget == 'en';

    if (isEnglish) {
      _germanWords = ['Hello', 'Thank you', 'Please', 'Goodbye'];
      _englishWords = ['नमस्ते', 'धन्यवाद', 'कृपया', 'अलविदा'];
      _solutionPairs = {
        'Hello': 'नमस्ते',
        'Thank you': 'धन्यवाद',
        'Please': 'कृपया',
        'Goodbye': 'अलविदा',
      };
      _clozeSentence = 'I _____ from India.';
      _clozeTranslation = 'मैं भारत से हूँ।';
      _clozeBlank = 'come';
      _clozeOptions = ['come', 'comes', 'live'];

      _typePrompt = 'The coffee is _____.';
      _typeTranslation = 'The coffee is hot.';
      _typeTarget = 'hot';
      _typeHint = 'Translate "hot" into English';

      _dialoguePartnerName = 'Alex';
      _dialoguePartnerMessage = 'Hello! What is your name?';
      _dialoguePartnerTranslation = 'Hello! What is your name?';
      _dialogueOptions = [
        {'text': 'My name is Rohan.', 'isCorrect': true},
        {'text': 'Goodbye!', 'isCorrect': false},
        {'text': 'No, thank you.', 'isCorrect': false},
      ];

      _listenSelectSentence = 'Two coffees and one water, please.';
      _listenSelectQuestion = 'What is the customer ordering?';
      _listenSelectOptions = [
        {'text': 'Two coffees and one water', 'isCorrect': true},
        {'text': 'One tea and two beers', 'isCorrect': false},
        {'text': 'A slice of chocolate cake', 'isCorrect': false},
      ];
      _sprechenPrompt = 'Hello! How are you?';
      _sprechenTranslation = 'नमस्ते! आप कैसे हैं?';
    } else {
      _clozeSentence = 'Ich _____ aus Indien.';
      _clozeTranslation = 'I come from India.';
      _clozeBlank = 'komme';
      _clozeOptions = ['komme', 'kommst', 'wohne'];

      _typePrompt = 'Der Kaffee ist _____.';
      _typeTranslation = 'The coffee is hot.';
      _typeTarget = 'heiß';
      _typeHint = 'Translate "hot" into German';

      _dialoguePartnerName = 'Florian';
      _dialoguePartnerMessage = 'Hallo! Wie heißt du?';
      _dialoguePartnerTranslation = 'Hello! What is your name?';
      _dialogueOptions = [
        {'text': 'Ich heiße Alex.', 'isCorrect': true},
        {'text': 'Auf Wiedersehen!', 'isCorrect': false},
        {'text': 'Nein, danke.', 'isCorrect': false},
      ];

      _listenSelectSentence = 'Zwei Kaffee und ein Wasser, bitte.';
      _listenSelectQuestion = 'What is the customer ordering?';
      _listenSelectOptions = [
        {'text': 'Two coffees and one water', 'isCorrect': true},
        {'text': 'One tea and two beers', 'isCorrect': false},
        {'text': 'A slice of chocolate cake', 'isCorrect': false},
      ];
    }
    debugPrint('🎧 [_initStagesData] Fallback mode (all 8 stages active, isEnglish: $isEnglish)');
    _precacheAllVocab();
  }

  void _applyStages(List<dynamic> stages) {
    final activeTypes = <String>[];
    for (final rawStage in stages) {
      if (rawStage is! Map) continue;
      final stage = Map<String, dynamic>.from(rawStage);
      final type = stage['type']?.toString();

      if ((type == 'match_pairs' || type == 'word_match') && stage['pairs'] is List) {
        final parsed = LessonStageParser.parseWordMatch(stage);
        if (parsed != null) {
          _germanWords = parsed.germanWords;
          _englishWords = parsed.englishWords;
          _solutionPairs = parsed.solutionPairs;
          activeTypes.add('word_match');
        }
      } else if (type == 'listen_tap') {
        final parsed = LessonStageParser.parseListenTap(stage);
        if (parsed != null) {
          if (parsed.targetSentence.isNotEmpty) {
            _listenTargetSentence = parsed.targetSentence;
            _listenTarget = parsed.targetWords;
          }
          if (parsed.wordBank.isNotEmpty) {
            _listenBank = parsed.wordBank;
          }
          _listenAudioUrl = parsed.audioUrl;
          activeTypes.add('listen_tap');
        }
      } else if (type == 'cloze_test' || type == 'cloze') {
        final sentence = (stage['sentence'] ?? stage['prompt'] ?? '').toString().trim();
        if (sentence.isNotEmpty) _clozeSentence = sentence;
        final trans = (stage['translation'] ?? '').toString().trim();
        if (trans.isNotEmpty) _clozeTranslation = trans;
        final blank = (stage['blank'] ?? stage['target'] ?? stage['correctOption'] ?? stage['correctAnswer'] ?? stage['answer'] ?? '').toString().trim();
        if (blank.isNotEmpty) _clozeBlank = blank;
        if (stage['options'] is List && (stage['options'] as List).isNotEmpty) {
          _clozeOptions = (stage['options'] as List)
              .map((o) => (o is Map ? (o['text'] ?? '') : o).toString().trim())
              .where((o) => o.isNotEmpty)
              .toList();
        }
        activeTypes.add('cloze_test');
      } else if (type == 'sentence_builder') {
        final prompt = stage['prompt']?.toString().trim();
        if (prompt != null && prompt.isNotEmpty) {
          _sentencePrompt = prompt;
        }
        final target = stage['targetSentence']?.toString().trim() ?? '';
        if (target.isNotEmpty) {
          _builderTargetSentence = target;
          _builderTarget = target
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .toList();
        }
        if (stage['tokens'] is List && (stage['tokens'] as List).isNotEmpty) {
          _builderBank = (stage['tokens'] as List)
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
            ..shuffle();
        } else if (_builderTarget.isNotEmpty) {
          _builderBank = List<String>.from(_builderTarget)..shuffle();
        }
        activeTypes.add('sentence_builder');
      } else if (type == 'type_word' || type == 'type_input') {
        final prompt = (stage['prompt'] ?? stage['sentence'] ?? '').toString().trim();
        if (prompt.isNotEmpty) _typePrompt = prompt;
        final trans = (stage['translation'] ?? stage['nativeMeaning'] ?? '').toString().trim();
        if (trans.isNotEmpty) _typeTranslation = trans;
        final target = (stage['target'] ?? stage['targetWord'] ?? stage['word'] ?? stage['correctAnswer'] ?? '').toString().trim();
        if (target.isNotEmpty) _typeTarget = target;
        final hint = (stage['hint'] ?? '').toString().trim();
        if (hint.isNotEmpty) _typeHint = hint;
        activeTypes.add('type_word');
      } else if (type == 'dialogue_bubble' || type == 'dialogue') {
        final name = (stage['partnerName'] ?? stage['speaker'] ?? 'Florian').toString().trim();
        if (name.isNotEmpty) _dialoguePartnerName = name;
        final msg = (stage['partnerMessage'] ?? stage['message'] ?? stage['prompt'] ?? '').toString().trim();
        if (msg.isNotEmpty) _dialoguePartnerMessage = msg;
        final trans = (stage['translation'] ?? '').toString().trim();
        if (trans.isNotEmpty) _dialoguePartnerTranslation = trans;
        if (stage['options'] is List && (stage['options'] as List).isNotEmpty) {
          final correctOpt = (stage['correctOption'] ?? stage['correctAnswer'] ?? '').toString().trim();
          _dialogueOptions = (stage['options'] as List).asMap().entries.map((entry) {
            final o = entry.value;
            if (o is Map) return Map<String, dynamic>.from(o);
            final optText = o.toString().trim();
            final isCorrect = correctOpt.isNotEmpty
                ? optText.toLowerCase() == correctOpt.toLowerCase()
                : (entry.key == 0);
            return {'text': optText, 'isCorrect': isCorrect};
          }).toList();
        }
        activeTypes.add('dialogue_bubble');
      } else if (type == 'listen_select' || type == 'listen_comprehension') {
        final sentence = (stage['spokenGerman'] ?? stage['sentence'] ?? stage['targetSentence'] ?? '').toString().trim();
        if (sentence.isNotEmpty) _listenSelectSentence = sentence;
        final question = (stage['question'] ?? stage['prompt'] ?? '').toString().trim();
        if (question.isNotEmpty) _listenSelectQuestion = question;
        final audio = stage['audioUrl']?.toString().trim();
        _listenSelectAudioUrl = (audio != null && audio.isNotEmpty) ? audio : '';
        if (stage['options'] is List && (stage['options'] as List).isNotEmpty) {
          final correctOpt = (stage['correctOption'] ?? stage['correctAnswer'] ?? '').toString().trim();
          _listenSelectOptions = (stage['options'] as List).asMap().entries.map((entry) {
            final o = entry.value;
            if (o is Map) return Map<String, dynamic>.from(o);
            final optText = o.toString().trim();
            final isCorrect = correctOpt.isNotEmpty
                ? optText.toLowerCase() == correctOpt.toLowerCase()
                : (entry.key == 0);
            return {'text': optText, 'isCorrect': isCorrect};
          }).toList();
        }
        activeTypes.add('listen_select');
      } else if (type == 'sprechen') {
        final prompt = stage['prompt']?.toString().trim();
        if (prompt != null && prompt.isNotEmpty) {
          _sprechenPrompt = prompt;
        }
        final trans = stage['translation']?.toString().trim();
        if (trans != null && trans.isNotEmpty) {
          _sprechenTranslation = trans;
        }
        if (stage['minAccuracy'] is num) {
          _sprechenMinAccuracy = (stage['minAccuracy'] as num).toInt();
        }
        final audio = stage['audioUrl']?.toString().trim();
        _sprechenAudioUrl = (audio != null && audio.isNotEmpty) ? audio : '';
        if (stage['karaokeData'] != null) {
          final kd = stage['karaokeData'];
          if (kd is Map && kd['words'] is List) {
            _sprechenKaraokeWords = (kd['words'] as List)
                .map((w) => KaraokeWord.fromJson(Map<String, dynamic>.from(w as Map)))
                .toList();
          } else if (kd is List) {
            _sprechenKaraokeWords = kd
                .map((w) => KaraokeWord.fromJson(Map<String, dynamic>.from(w as Map)))
                .toList();
          } else if (kd is Map && kd['sentences'] is List && (kd['sentences'] as List).isNotEmpty) {
            final firstS = kd['sentences'][0];
            if (firstS is Map && firstS['words'] is List) {
              _sprechenKaraokeWords = (firstS['words'] as List)
                  .map((w) => KaraokeWord.fromJson(Map<String, dynamic>.from(w as Map)))
                  .toList();
            }
          }
        }
        activeTypes.add('sprechen');
      }
    }

    if (_sprechenKaraokeWords.isEmpty && _sprechenPrompt.isNotEmpty) {
      final words = _sprechenPrompt.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      _sprechenKaraokeWords = words
          .asMap()
          .entries
          .map((e) => KaraokeWord(
                word: e.value,
                clean: e.value.replaceAll(RegExp(r"[.,/#!$%^&*;:{}=\-_`~()?'«»„“”’]"), '').trim(),
                start: e.key * 0.5,
                end: (e.key * 0.5) + 0.45,
              ))
          .toList();
    }

    if (activeTypes.isNotEmpty) {
      _activeStageTypes = activeTypes;
    } else {
      _activeStageTypes = [
        'word_match',
        'listen_tap',
        'cloze_test',
        'sentence_builder',
        'type_word',
        'dialogue_bubble',
        'listen_select',
        'sprechen',
      ];
    }
    if (_initialTotalStages == 0) {
      _initialTotalStages = _activeStageTypes.length;
    }

    debugPrint('🎯 [_applyStages] Active stage sequence: $_activeStageTypes (total: ${_activeStageTypes.length})');
    _precacheAllVocab();
    _triggerPrewarmForStage(0);
    _triggerPrewarmForStage(1);
  }

  void _triggerPrewarmForNext() {
    _triggerPrewarmForStage(_currentStage + 1);
  }

  void _triggerPrewarmForStage(int index) {
    if (index < 0 || index >= _activeStageTypes.length) return;
    final stageType = _activeStageTypes[index];
    final words = <String>[];

    switch (stageType) {
      case 'sentence_builder':
        words.addAll(_builderBank);
        if (_builderTargetSentence.isNotEmpty) {
          words.add(_builderTargetSentence);
        }
        break;
      case 'cloze_test':
        words.addAll(_clozeOptions);
        if (_clozeBlank.isNotEmpty) words.add(_clozeBlank);
        if (_clozeSentence.isNotEmpty) words.add(_clozeSentence);
        break;
      case 'type_word':
        if (_typeTarget.isNotEmpty) words.add(_typeTarget);
        if (_typePrompt.isNotEmpty) words.add(_typePrompt);
        break;
      case 'dialogue_bubble':
        if (_dialoguePartnerMessage.isNotEmpty) words.add(_dialoguePartnerMessage);
        for (final opt in _dialogueOptions) {
          if (opt['text'] != null) words.add(opt['text'].toString());
        }
        break;
      case 'listen_select':
        if (_listenSelectSentence.isNotEmpty) words.add(_listenSelectSentence);
        break;
      case 'listen_tap':
        words.addAll(_listenBank);
        if (_listenTargetSentence.isNotEmpty) words.add(_listenTargetSentence);
        break;
      case 'word_match':
        words.addAll(_germanWords);
        break;
      case 'sprechen':
        if (_sprechenPrompt.isNotEmpty) words.add(_sprechenPrompt);
        break;
    }

    TtsService().prewarmForStage(stageType, words);
  }

  void _precacheAllVocab() {
    // Pre-cache all lesson vocabulary words in the background for zero-latency instant taps
    final allVocab = <String>{};
    allVocab.addAll(_germanWords);
    allVocab.addAll(_listenTarget);
    allVocab.addAll(_listenBank);
    allVocab.addAll(_builderTarget);
    allVocab.addAll(_builderBank);
    allVocab.addAll(_clozeOptions);
    if (_clozeBlank.isNotEmpty) allVocab.add(_clozeBlank);
    if (_typeTarget.isNotEmpty) allVocab.add(_typeTarget);
    for (final opt in _dialogueOptions) {
      if (opt['text'] != null) {
        allVocab.addAll(opt['text'].toString().split(RegExp(r'\s+')));
      }
    }
    for (final w in _sprechenKaraokeWords) {
      allVocab.add(w.word);
    }
    if (allVocab.isNotEmpty) {
      TtsService().precacheWords(allVocab.toList());
    }
  }

  void _onGermanMatchTap(String word) {
    if (_isEvaluatingMatch) return;
    if (_matchedGerman.contains(word)) return;
    SoundEffectsService().playPop();
    TtsService().speakWord(word);
    setState(() {
      _selectedGerman = word;
      _evaluateMatch();
    });
  }

  void _onEnglishMatchTap(String word) {
    if (_isEvaluatingMatch) return;
    if (_matchedEnglish.contains(word)) return;
    SoundEffectsService().playPop();
    setState(() {
      _selectedEnglish = word;
      _evaluateMatch();
    });
  }

  void _evaluateMatch() {
    if (_selectedGerman != null && _selectedEnglish != null) {
      _isEvaluatingMatch = true;
      final german = _selectedGerman!;
      final english = _selectedEnglish!;

      if (_solutionPairs[german] == english) {
        // Correct Match: Flashes Emerald Green, triggers SoundEffectsService().playCorrect(), smoothly transitions to completed state
        _correctGermanWord = german;
        _correctEnglishWord = english;
        _selectedGerman = null;
        _selectedEnglish = null;
        SoundEffectsService().playCorrect();

        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) {
            setState(() {
              _matchedGerman.add(german);
              _matchedEnglish.add(english);
              _correctGermanWord = null;
              _correctEnglishWord = null;
              _isEvaluatingMatch = false;

              // Stage Complete: When all pairs match (including 5th pair), trigger fanfare
              if (_matchedGerman.length == _germanWords.length) {
                _matchFinished = true;
                SoundEffectsService().playFanfare();
                _triggerPrewarmForNext();
              }
            });
          }
        });
      } else {
        // Wrong Mismatch: Flashes Soft Red (#FEF2F2, border #EF4444, 2.5px width), triggers SoundEffectsService().playWrong(), subtle shake animation (250ms), smoothly clears after 400ms
        _wrongGermanWord = german;
        _wrongEnglishWord = english;
        SoundEffectsService().playWrong();
        _handleIncorrectAnswer();

        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            setState(() {
              if (_selectedGerman == german) _selectedGerman = null;
              if (_selectedEnglish == english) _selectedEnglish = null;
              _wrongGermanWord = null;
              _wrongEnglishWord = null;
              _isEvaluatingMatch = false;
            });
          }
        });
      }
    }
  }

  // ── Stage: Cloze Test Handlers ────────────────────────────────────
  void _onClozeOptionTap(String option) {
    TtsService().speakWord(option);
    setState(() {
      _clozeSelectedOption = option;
      _clozeCorrect = null;
    });
  }

  void _evaluateCloze() {
    if (_clozeSelectedOption == null) return;
    final isCorrect = _clozeSelectedOption!.trim().toLowerCase() == _clozeBlank.trim().toLowerCase();
    setState(() {
      _clozeCorrect = isCorrect;
    });
    _triggerPrewarmForNext();
    if (!isCorrect) {
      _handleIncorrectAnswer();
    }
  }

  // ── Stage: Type Word Handlers ─────────────────────────────────────
  void _addUmlautToInput(String char) {
    final text = _typeWordController.text;
    final selection = _typeWordController.selection;
    final newText = (selection.start >= 0 && selection.end >= 0)
        ? text.replaceRange(selection.start, selection.end, char)
        : text + char;
    final newCursorPos = (selection.start >= 0) ? selection.start + char.length : newText.length;
    _typeWordController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
    setState(() => _typeCorrect = null);
  }

  void _evaluateTypeWord() {
    final typed = _typeWordController.text.trim().toLowerCase();
    if (typed.isEmpty) return;
    FocusScope.of(context).unfocus();
    _typeWordController.clear();

    final target = _typeTarget.trim().toLowerCase();

    // Support standard digraph equivalents (ä -> ae, ö -> oe, ü -> ue, ß -> ss)
    final normTyped = typed.replaceAll('ä', 'ae').replaceAll('ö', 'oe').replaceAll('ü', 'ue').replaceAll('ß', 'ss');
    final normTarget = target.replaceAll('ä', 'ae').replaceAll('ö', 'oe').replaceAll('ü', 'ue').replaceAll('ß', 'ss');

    final isCorrect = (typed == target) || (normTyped == normTarget);
    if (isCorrect) {
      TtsService().speakWord(_typeTarget);
    }
    setState(() {
      _typeCorrect = isCorrect;
    });
    _triggerPrewarmForNext();
    if (!isCorrect) {
      _handleIncorrectAnswer();
    }
  }

  // ── Stage: Dialogue Bubble Handlers ───────────────────────────────
  void _onDialogueOptionTap(int index) {
    if (index >= _dialogueOptions.length) return;
    final opt = _dialogueOptions[index];
    final text = (opt['text'] ?? '').toString();
    if (text.isNotEmpty) {
      TtsService().speakSentence(text);
    }
    setState(() {
      _dialogueSelectedIdx = index;
      _dialogueCorrect = null;
    });
  }

  void _evaluateDialogue() {
    if (_dialogueSelectedIdx == null || _dialogueSelectedIdx! >= _dialogueOptions.length) return;
    final opt = _dialogueOptions[_dialogueSelectedIdx!];
    final isCorrect = (opt['isCorrect'] != null) ? (opt['isCorrect'] == true) : (_dialogueSelectedIdx == 0);
    setState(() {
      _dialogueCorrect = isCorrect;
    });
    _triggerPrewarmForNext();
    if (!isCorrect) {
      _handleIncorrectAnswer();
    }
  }

  // ── Stage: Listen Select Handlers ─────────────────────────────────
  void _onListenSelectOptionTap(int index) {
    setState(() {
      _listenSelectSelectedIdx = index;
      _listenSelectCorrect = null;
    });
  }

  void _evaluateListenSelect() {
    if (_listenSelectSelectedIdx == null || _listenSelectSelectedIdx! >= _listenSelectOptions.length) return;
    final opt = _listenSelectOptions[_listenSelectSelectedIdx!];
    final isCorrect = (opt['isCorrect'] != null) ? (opt['isCorrect'] == true) : (_listenSelectSelectedIdx == 0);
    setState(() {
      _listenSelectCorrect = isCorrect;
    });
    _triggerPrewarmForNext();
    if (!isCorrect) {
      _handleIncorrectAnswer();
    }
  }

  void _triggerSprechenAutoPlay() {
    if (_hasPlayedSprechenDemo) return;
    _sprechenAutoPlayTimer?.cancel();
    _sprechenAutoPlayTimer = Timer(const Duration(seconds: 1), () {
      final currentType = (_currentStage < _activeStageTypes.length)
          ? _activeStageTypes[_currentStage]
          : null;
      if (mounted && currentType == 'sprechen' && !_hasPlayedSprechenDemo) {
        _playSprechenDemo();
      }
    });
  }

  Future<void> _playSprechenDemo() async {
    _hasPlayedSprechenDemo = true;
    _ttsHighlightTimer?.cancel();
    final rawUrl = _sprechenAudioUrl.isNotEmpty ? _sprechenAudioUrl : '';
    final url = _resolveAudioUrl(rawUrl);

    if (url.isNotEmpty) {
      try {
        if (!mounted) return;
        final cachedFile = await CacheService().getCachedAudioFile(url);
        if (!mounted) return;
        await _audioPlayer.stop();
        if (!mounted) return;
        setState(() {
          _isSprechenDemoPlaying = true;
        });
        if (!mounted) return;
        if (cachedFile != null) {
          debugPrint('🔊 [_playSprechenDemo] Playing from Tier-2 disk audio cache: ${cachedFile.path}');
          await _audioPlayer.play(DeviceFileSource(cachedFile.path));
        } else {
          debugPrint('🔊 [_playSprechenDemo] Starting studio reference playback: $url');
          await _audioPlayer.play(UrlSource(url));
          PrefetchService().prefetchAudioUrl(url);
        }
        return;
      } catch (e) {
        debugPrint('⚠️ [_playSprechenDemo] Studio audio error: $e, falling back to TTS');
      }
    }

    // Machine TTS reference playback (stationary text, no artificial desynced timer)
    if (_sprechenPrompt.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _isSprechenDemoPlaying = true;
      });

      await TtsService().speakSentence(_sprechenPrompt);
      if (mounted) {
        setState(() {
          _isSprechenDemoPlaying = false;
        });
      }
    }
  }

  Future<void> _toggleSpeaking() async {
    if (_isSprechenDemoPlaying) {
      _ttsHighlightTimer?.cancel();
      await _audioPlayer.stop();
      await TtsService().stop();
      if (mounted) {
        setState(() {
          _isSprechenDemoPlaying = false;
        });
      }
    }

    // 1. Prevent Overlapping Sessions
    if (_speechSessionState != SpeechSessionState.idle) {
      if (_speechSessionState == SpeechSessionState.listening) {
        _silenceTimer?.cancel();
        _speechSessionState = SpeechSessionState.stopping;
        try {
          await _speech?.stop();
        } catch (_) {}
        if (mounted) {
          setState(() => _speechSessionState = SpeechSessionState.idle);
          _evaluateSpeechPronunciation();
        }
      }
      return;
    }

    // 2. Cooldown check: 300ms - 500ms safety backoff after any error
    final cooldownRemaining =
        400 - DateTime.now().difference(_lastSpeechErrorTime).inMilliseconds;
    if (cooldownRemaining > 0) {
      await Future.delayed(Duration(milliseconds: cooldownRemaining));
    }

    // 3. Runtime Permission Verification
    final micPerm = await Permission.microphone.request();
    if (!micPerm.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFDC2626),
            content: Text(
                'Microphone permission is required for speech recognition.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // 4. Native Recognition Availability Check (3-Tier Engine Resolution)
    final engineRes = await SpeechLifecycleBridge.ensureOptimalSpeechEngine();
    if (!engineRes.isAvailable) {
      if (mounted) {
        _showSpeechUnavailableDialog();
      }
      return;
    }

    setState(() {
      _speechSessionState = SpeechSessionState.listening;
      _spokenText = '';
      _speechAccuracy = 0;
      _speechPassed = null;
      _evaluatedTokens = [];
    });

    try {
      // 5. Create a fresh recognizer instance for this listening session
      _speech ??= stt.SpeechToText();
      bool available = _speechInitialized;
      if (!available) {
        available = await _speech!.initialize(
          onError: (val) {
            debugPrint('STT error: ${val.errorMsg}');
            final msg = val.errorMsg.toLowerCase();
            if (msg.contains('error_busy') || msg.contains('busy')) {
              debugPrint('⚠️ [STT] Recognizer busy: releasing and backing off');
              _lastSpeechErrorTime = DateTime.now();
              _forceReleaseSpeechRecognizer();
            } else if (msg.contains('error_permission')) {
              _lastSpeechErrorTime = DateTime.now();
              _forceReleaseSpeechRecognizer();
            }
          },
          onStatus: (val) {
            debugPrint('STT status: $val');
            if (val == 'done' || val == 'notListening') {
              if (mounted && _isSpeaking) {
                _silenceTimer?.cancel();
                _silenceTimer = Timer(const Duration(milliseconds: 2000), () {
                  if (mounted && _isSpeaking) {
                    setState(
                        () => _speechSessionState = SpeechSessionState.idle);
                    _evaluateSpeechPronunciation();
                  }
                });
              }
            }
          },
        );
        _speechInitialized = available;
      }

      if (!available) {
        debugPrint(
            '⚠️ Speech recognition unavailable; fallback test simulation');
        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(milliseconds: 1800), () {
          if (mounted && _isSpeaking) {
            setState(() {
              _speechSessionState = SpeechSessionState.idle;
              _spokenText = _sprechenPrompt;
            });
            _evaluateSpeechPronunciation();
          }
        });
        return;
      }

      final currentTarget =
          ref.read(gamificationStatusProvider).value?.targetLanguage ?? 'de';
      final isEnglish = currentTarget == 'en';
      String targetLocaleId = isEnglish ? 'en_GB' : 'de_DE';
      try {
        final locales = await _speech!.locales();
        if (isEnglish) {
          final gbMatch = locales
              .where((l) =>
                  l.localeId.toLowerCase().contains('en_gb') ||
                  l.localeId.toLowerCase().contains('en-gb'))
              .firstOrNull;
          final anyEn = locales
              .where((l) => l.localeId.toLowerCase().startsWith('en'))
              .firstOrNull;
          if (gbMatch != null) {
            targetLocaleId = gbMatch.localeId;
          } else if (anyEn != null) {
            targetLocaleId = anyEn.localeId;
          }
        } else {
          final deMatch = locales
              .where((l) => l.localeId.toLowerCase().startsWith('de'))
              .firstOrNull;
          if (deMatch != null) {
            targetLocaleId = deMatch.localeId;
          }
        }
        debugPrint(
            '🗣️ [Speech Recognition] Using target locale: $targetLocaleId (isEnglish: $isEnglish)');
      } catch (e) {
        debugPrint('⚠️ Error querying locales: $e');
      }

      await _speech!.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _spokenText = result.recognizedWords.trim();
            });
          }
          if (_spokenText.isNotEmpty) {
            _silenceTimer?.cancel();
            _silenceTimer = Timer(const Duration(milliseconds: 3000), () {
              if (mounted && _isSpeaking) {
                _speech?.stop();
                setState(() => _speechSessionState = SpeechSessionState.idle);
                _evaluateSpeechPronunciation();
              }
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          localeId: targetLocaleId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Speech listen exception: $e');
      _lastSpeechErrorTime = DateTime.now();
      await _forceReleaseSpeechRecognizer();
      if (mounted) {
        setState(() {
          _speechSessionState = SpeechSessionState.idle;
          _spokenText = _sprechenPrompt;
        });
        _evaluateSpeechPronunciation();
      }
    }
  }

  void _evaluateSpeechPronunciation() {
    _silenceTimer?.cancel();
    _forceReleaseSpeechRecognizer();
    if (!mounted) return;

    final targetText = _sprechenPrompt.isNotEmpty ? _sprechenPrompt : 'Guten Tag! Wie geht es dir?';
    final currentTarget = ref.read(gamificationStatusProvider).value?.targetLanguage ?? 'de';
    final threshold = _sprechenMinAccuracy > 0 ? _sprechenMinAccuracy : 75;

    final evalResult = PronunciationEvaluator.evaluate(
      targetSentence: targetText,
      spokenSentence: _spokenText,
      language: currentTarget,
      minAccuracyThreshold: threshold,
    );

    final accuracy = evalResult.accuracyPercentage;
    final isPassed = evalResult.isPassed;

    debugPrint('🗣️ [_evaluateSpeechPronunciation] Target: "$targetText" | Spoken: "$_spokenText" | Accuracy: $accuracy% | Passed: $isPassed');

    setState(() {
      _speechAccuracy = accuracy;
      _speechPassed = isPassed;
      _evaluatedTokens = evalResult.tokens;
    });
    _triggerPrewarmForNext();

    final isEn = currentTarget == 'en';
    final nLang = ref.read(gamificationStatusProvider).value?.nativeLanguage ?? (isEn ? 'hi' : 'en');

    if (isPassed) {
      final successText = isEn
          ? (nLang == 'hi'
              ? 'शानदार उच्चारण! ($accuracy% मैच) 🎉'
              : (nLang == 'mr'
                  ? 'उत्कृष्ट उच्चार! ($accuracy% मॅच) 🎉'
                  : 'Great pronunciation! ($accuracy% match) 🎉'))
          : 'Ausgezeichnet! ($accuracy% match) 🎉';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF15803D),
          content: Text(successText),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final retryText = isEn
          ? (nLang == 'hi'
              ? 'मैच $accuracy% — पास होने के लिए $threshold% आवश्यक है। पुनः प्रयास करें!'
              : (nLang == 'mr'
                  ? 'मॅच $accuracy% — पास होण्यासाठी $threshold% आवश्यक आहे. पुन्हा प्रयत्न करा!'
                  : 'Match $accuracy% — Need $threshold% or higher to pass. Try again!'))
          : 'Match $accuracy% — Need $threshold% or higher to pass. Try again!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text(retryText),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _handleIncorrectAnswer() {
    _mistakesCount++;
    // 1. Mistakes Review Loop: re-enqueue stage at end of active stages (Objective 3)
    if (!_currentStageReEnqueued && _currentStage < _activeStageTypes.length) {
      _currentStageReEnqueued = true;
      final currentType = _activeStageTypes[_currentStage];
      _activeStageTypes.add(currentType);
      debugPrint('🔁 [Mistakes Review] Re-enqueued $currentType at end of stages. Total stages: ${_activeStageTypes.length}');
    }

    // 2. Connect Hearts/Oxygen Deduction (Objective 2)
    ref.read(gamificationStatusProvider.notifier).deductOxygen();

    // 3. If oxygen depleted, pause and prompt refill modal
    final currentOxygen = ref.read(gamificationStatusProvider).value?.oxygen ?? 0;
    if (currentOxygen <= 0) {
      _showOutOfOxygenDialog();
    }
  }

  void _showOutOfOxygenDialog() {
    _audioPlayer.pause();
    TtsService().stop();
    if (mounted) {
      setState(() {
        _isPlayingAudio = false;
        _isSprechenDemoPlaying = false;
      });
    }

    OutOfOxygenSheet.show(
      context,
      onRefilled: () {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  void _showSpeechUnavailableDialog() {
    _forceReleaseSpeechRecognizer();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Icon(
                  Icons.mic_off_rounded,
                  size: 48,
                  color: Color(0xFFE11D48),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Speech Recognition Unavailable',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your device does not have a compatible speech recognition engine installed. You can still complete this lesson without speaking.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                // Action 1: Duolingo Parity letPass = true (Pass this exercise & proceed)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (mounted) {
                        setState(() {
                          _spokenText = _sprechenPrompt;
                          _speechSessionState = SpeechSessionState.idle;
                        });
                        _evaluateSpeechPronunciation();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C9A7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'PASS THIS EXERCISE & CONTINUE',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Action 2: Snooze speaking exercises
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref
                          .read(speechPreferencesProvider.notifier)
                          .snoozeSpeakingExercises();
                      if (mounted) {
                        setState(() {
                          _spokenText = _sprechenPrompt;
                          _speechSessionState = SpeechSessionState.idle;
                        });
                        _evaluateSpeechPronunciation();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF64748B),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'TURN OFF SPEAKING FOR 1 HOUR',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _resetStageStateForType(String stageType) {
    switch (stageType) {
      case 'word_match':
      case 'match_pairs':
        _matchedGerman.clear();
        _matchedEnglish.clear();
        _selectedGerman = null;
        _selectedEnglish = null;
        _wrongGermanWord = null;
        _wrongEnglishWord = null;
        _correctGermanWord = null;
        _correctEnglishWord = null;
        _matchFinished = false;
        _isEvaluatingMatch = false;
        break;
      case 'listen_tap':
        _listenSelectedIndices.clear();
        _listenCorrect = null;
        break;
      case 'cloze_test':
      case 'cloze':
        _clozeSelectedOption = null;
        _clozeCorrect = null;
        break;
      case 'sentence_builder':
        _builderSelectedIndices.clear();
        _builderCorrect = null;
        break;
      case 'type_word':
      case 'type_input':
        _typeWordController.clear();
        _typeCorrect = null;
        break;
      case 'dialogue_bubble':
      case 'dialogue':
        _dialogueSelectedIdx = null;
        _dialogueCorrect = null;
        break;
      case 'listen_select':
      case 'listen_comprehension':
        _listenSelectSelectedIdx = null;
        _listenSelectCorrect = null;
        break;
      case 'sprechen':
        _spokenText = '';
        _speechAccuracy = 0;
        _speechPassed = null;
        _speechSessionState = SpeechSessionState.idle;
        _hasPlayedSprechenDemo = false;
        _evaluatedTokens = [];
        break;
    }
  }

  void _nextStage() {
    _ttsHighlightTimer?.cancel();
    _sprechenAutoPlayTimer?.cancel();
    _forceReleaseSpeechRecognizer();
    _audioPlayer.pause();
    TtsService().stop();
    _currentStageReEnqueued = false;
    setState(() {
      _isPlayingAudio = false;
      _isSprechenDemoPlaying = false;
      _currentStage++;
    });
    if (_currentStage < _activeStageTypes.length) {
      _resetStageStateForType(_activeStageTypes[_currentStage]);
    }
    TtsService().warmUp();
    if (_currentStage < _activeStageTypes.length) {
      final nextType = _activeStageTypes[_currentStage];
      if (nextType == 'listen_tap') {
        _prepareListenAudio();
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && _currentStage < _activeStageTypes.length && _activeStageTypes[_currentStage] == 'listen_tap') {
            _playListenAudio();
          }
        });
      } else if (nextType == 'sprechen') {
        _triggerSprechenAutoPlay();
      } else if (nextType == 'dialogue_bubble') {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && _currentStage < _activeStageTypes.length && _activeStageTypes[_currentStage] == 'dialogue_bubble') {
            TtsService().speakSentence(_dialoguePartnerMessage);
          }
        });
      } else if (nextType == 'listen_select') {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted && _currentStage < _activeStageTypes.length && _activeStageTypes[_currentStage] == 'listen_select') {
            _playListenSelectAudio();
          }
        });
      }
    }
  }

  Future<void> _finishLesson() async {
    final xp = _earnedXp;
    final pearls = _earnedPearls;
    final accuracy = _calculatedAccuracy;

    // Complete node on archipelago map and save gamification stats to backend
    await ref.read(pathNodesProvider.notifier).completeNode(
      widget.nodeIndex,
      stars: accuracy == 100 ? 3 : (accuracy >= 80 ? 2 : 1),
      scorePct: accuracy,
      xp: xp,
      pearls: pearls,
    );

    await AdService().incrementLessonCount();
    if (!mounted) return;
    await AdService().showInterstitialIfEligible(
      onDone: () {
        if (mounted) {
          if (context.canPop()) {
            context.pop(true);
          } else {
            context.go('/home');
          }
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingLessonDetails) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 26),
            onPressed: () => context.go('/home'),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation(Color(0xFF10B981)),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Preparing Lesson...',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Loading interactive challenges',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final progress = _totalStages > 0
        ? (_currentStage / _totalStages).clamp(0.0, 1.0)
        : 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: !_isCelebrationStage
          ? AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 26),
                onPressed: () => context.go('/home'),
              ),
              title: ClipRRect(
                borderRadius: BorderRadius.circular(9999),
                child: SizedBox(
                  height: 12,
                  child: LinearProgressIndicator(
                    value: progress == 0 ? 0.08 : progress,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                  ),
                ),
              ),
              actions: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite_rounded, color: Color(0xFFFF4B4B), size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${ref.watch(gamificationStatusProvider).value?.oxygen ?? 5}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: const Color(0xFFFF4B4B),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentStageView(),
        ),
      ),
    );
  }

  String get _targetLang => ref.read(gamificationStatusProvider).value?.targetLanguage ?? 'de';
  String get _nativeLang => ref.read(gamificationStatusProvider).value?.nativeLanguage ?? (_targetLang == 'en' ? 'hi' : 'en');
  bool get _isTargetEnglish => _targetLang == 'en';

  String _getStageTitle(String stageType) {
    final isEn = _isTargetEnglish;
    final nLang = _nativeLang;

    if (isEn) {
      if (nLang == 'hi') {
        switch (stageType) {
          case 'word_match':
          case 'match_pairs':
            return 'शब्दों के जोड़े मिलाइए';
          case 'listen_tap':
            return 'सुनकर वाक्य चुनिए';
          case 'sentence_builder':
            return 'अंग्रेजी वाक्य बनाइए';
          case 'sprechen':
            return 'अंग्रेजी में बोलिए';
          case 'cloze_test':
          case 'cloze':
            return 'रिक्त स्थान भरिए';
          case 'type_word':
          case 'type_input':
            return 'अंग्रेजी शब्द टाइप करें';
          case 'dialogue_bubble':
          case 'dialogue':
            return 'बातचीत का अभ्यास';
          case 'listen_select':
          case 'listen_comprehension':
            return 'सुनें और सही विकल्प चुनें';
          default:
            return 'चुनौती पूरी करें';
        }
      } else if (nLang == 'mr') {
        switch (stageType) {
          case 'word_match':
          case 'match_pairs':
            return 'शब्दांच्या जोड्या जुळवा';
          case 'listen_tap':
            return 'ऐकून वाक्य निवडा';
          case 'sentence_builder':
            return 'इंग्रजी वाक्य बनवा';
          case 'sprechen':
            return 'इंग्रजीत बोला';
          case 'cloze_test':
          case 'cloze':
            return 'गाळलेली जागा भरा';
          case 'type_word':
          case 'type_input':
            return 'इंग्रजी शब्द टाइप करा';
          case 'dialogue_bubble':
          case 'dialogue':
            return 'संभाषणाचा सराव';
          case 'listen_select':
          case 'listen_comprehension':
            return 'ऐका आणि योग्य पर्याय निवडा';
          default:
            return 'आव्हान पूर्ण करा';
        }
      } else {
        switch (stageType) {
          case 'word_match':
          case 'match_pairs':
            return 'Match the word pairs';
          case 'listen_tap':
            return 'Listen and tap what you hear';
          case 'sentence_builder':
            return 'Construct the English sentence';
          case 'sprechen':
            return 'Speak in English';
          case 'cloze_test':
          case 'cloze':
            return 'Fill in the blank';
          case 'type_word':
          case 'type_input':
            return 'Type the English word';
          case 'dialogue_bubble':
          case 'dialogue':
            return 'Conversation with $_dialoguePartnerName';
          case 'listen_select':
          case 'listen_comprehension':
            return 'Listen & Comprehend';
          default:
            return 'Complete the Challenge';
        }
      }
    } else {
      // German course
      if (nLang == 'hi') {
        switch (stageType) {
          case 'word_match':
          case 'match_pairs':
            return 'शब्दों के जोड़े मिलाइए';
          case 'listen_tap':
            return 'सुनकर वाक्य चुनिए';
          case 'sentence_builder':
            return 'जर्मन वाक्य बनाइए';
          case 'sprechen':
            return 'जर्मन में बोलिए (Auf Deutsch)';
          case 'cloze_test':
          case 'cloze':
            return 'रिक्त स्थान भरिए';
          case 'type_word':
          case 'type_input':
            return 'जर्मन शब्द टाइप करें';
          case 'dialogue_bubble':
          case 'dialogue':
            return 'बातचीत का अभ्यास';
          case 'listen_select':
          case 'listen_comprehension':
            return 'सुनें और सही विकल्प चुनें';
          default:
            return 'चुनौती पूरी करें';
        }
      } else if (nLang == 'mr') {
        switch (stageType) {
          case 'word_match':
          case 'match_pairs':
            return 'शब्दांच्या जोड्या जुळवा';
          case 'listen_tap':
            return 'ऐकून वाक्य निवडा';
          case 'sentence_builder':
            return 'जर्मन वाक्य बनवा';
          case 'sprechen':
            return 'जर्मनमध्ये बोला (Auf Deutsch)';
          case 'cloze_test':
          case 'cloze':
            return 'गाळलेली जागा भरा';
          case 'type_word':
          case 'type_input':
            return 'जर्मन शब्द टाइप करा';
          case 'dialogue_bubble':
          case 'dialogue':
            return 'संभाषणाचा सराव';
          case 'listen_select':
          case 'listen_comprehension':
            return 'ऐका आणि योग्य पर्याय निवडा';
          default:
            return 'आव्हान पूर्ण करा';
        }
      } else {
        switch (stageType) {
          case 'word_match':
          case 'match_pairs':
            return 'Match the word pairs';
          case 'listen_tap':
            return 'Listen and tap what you hear';
          case 'sentence_builder':
            return 'Construct the German sentence';
          case 'sprechen':
            return 'Pronounce Auf Deutsch';
          case 'cloze_test':
          case 'cloze':
            return 'Fill in the blank';
          case 'type_word':
          case 'type_input':
            return 'Type the German word';
          case 'dialogue_bubble':
          case 'dialogue':
            return 'Conversation with $_dialoguePartnerName';
          case 'listen_select':
          case 'listen_comprehension':
            return 'Listen & Comprehend';
          default:
            return 'Complete the Challenge';
        }
      }
    }
  }

  String _getStageSubtitle(String stageType) {
    final isEn = _isTargetEnglish;
    final nLang = _nativeLang;

    if (isEn) {
      if (nLang == 'hi') {
        switch (stageType) {
          case 'word_match':
          case 'match_pairs':
            return 'अंग्रेजी शब्द और उसके सही हिंदी अर्थ को छुएं।';
          case 'listen_tap':
            return 'ऑडियो ध्यान से सुनें और सुने गए शब्दों को क्रम से लगाएं।';
          case 'sentence_builder':
            return 'शब्दों को सही क्रम में लगाकर अंग्रेजी वाक्य बनाएं।';
          case 'sprechen':
            return 'माइक दबाएं और इको के साथ अंग्रेजी में बोलें।';
          case 'cloze_test':
          case 'cloze':
            return 'वाक्य पूरा करने के लिए सही अंग्रेजी शब्द चुनें।';
          case 'type_word':
          case 'type_input':
            return _typeHint.isNotEmpty ? _typeHint : 'खाली स्थान के लिए सही अंग्रेजी शब्द लिखें।';
          case 'dialogue_bubble':
          case 'dialogue':
            return 'बातचीत जारी रखने के लिए सबसे सही उत्तर चुनें।';
          case 'listen_select':
          case 'listen_comprehension':
            return _listenSelectQuestion.isNotEmpty ? _listenSelectQuestion : 'ऑडियो ध्यान से सुनें और सही उत्तर चुनें।';
          default:
            return 'दिए गए कार्य को पूरा करें।';
        }
      } else if (nLang == 'mr') {
        switch (stageType) {
          case 'word_match':
          case 'match_pairs':
            return 'इंग्रजी शब्द आणि त्याचा योग्य मराठी अर्थ टॅप करा.';
          case 'listen_tap':
            return 'ऑडिओ लक्षपूर्वक ऐका आणि ऐकलेले शब्द क्रमाने लावा.';
          case 'sentence_builder':
            return 'शब्दांना योग्य क्रमाने लावून इंग्रजी वाक्य बनवा.';
          case 'sprechen':
            return 'माइक टॅप करा आणि इकोसोबत इंग्रजीत बोला.';
          case 'cloze_test':
          case 'cloze':
            return 'वाक्य पूर्ण करण्यासाठी योग्य इंग्रजी शब्द निवडा.';
          case 'type_word':
          case 'type_input':
            return _typeHint.isNotEmpty ? _typeHint : 'रिकाम्या जागेसाठी योग्य इंग्रजी शब्द लिहा.';
          case 'dialogue_bubble':
          case 'dialogue':
            return 'संभाषण पुढे नेण्यासाठी सर्वात योग्य पर्याय निवडा.';
          case 'listen_select':
          case 'listen_comprehension':
            return _listenSelectQuestion.isNotEmpty ? _listenSelectQuestion : 'ऑडिओ लक्षपूर्वक ऐका आणि अचूक पर्याय निवडा.';
          default:
            return 'दिलेले कार्य पूर्ण करा.';
        }
      } else {
        switch (stageType) {
          case 'word_match':
          case 'match_pairs':
            return 'Tap an English word and its matching meaning.';
          case 'listen_tap':
            return 'Listen to the audio and arrange the words.';
          case 'sentence_builder':
            return 'Arrange the words to form the correct sentence.';
          case 'sprechen':
            return 'Tap the microphone and speak aloud to Echo the Dolphin.';
          case 'cloze_test':
          case 'cloze':
            return 'Tap the correct English word to complete the sentence.';
          case 'type_word':
          case 'type_input':
            return _typeHint.isNotEmpty ? _typeHint : 'Translate and spell the missing word correctly.';
          case 'dialogue_bubble':
          case 'dialogue':
            return 'Choose the most natural reply to continue the conversation.';
          case 'listen_select':
          case 'listen_comprehension':
            return _listenSelectQuestion.isNotEmpty ? _listenSelectQuestion : 'Listen carefully to the audio and select the right option.';
          default:
            return 'Complete the task.';
        }
      }
    } else {
      if (nLang == 'hi') {
        switch (stageType) {
          case 'word_match':
          case 'match_pairs':
            return 'जर्मन शब्द और उसके सही अर्थ को छुएं।';
          case 'listen_tap':
            return 'ऑडियो ध्यान से सुनें और सुने गए जर्मन शब्दों को चुनें।';
          case 'sentence_builder':
            return 'शब्दों को सही क्रम में लगाकर जर्मन वाक्य बनाएं।';
          case 'sprechen':
            return 'माइक दबाएं और इको के साथ जर्मन में बोलें।';
          case 'cloze_test':
          case 'cloze':
            return 'वाक्य पूरा करने के लिए सही जर्मन शब्द चुनें।';
          case 'type_word':
          case 'type_input':
            return _typeHint.isNotEmpty ? _typeHint : 'खाली स्थान के लिए सही जर्मन शब्द लिखें।';
          case 'dialogue_bubble':
          case 'dialogue':
            return 'बातचीत जारी रखने के लिए सबसे सही उत्तर चुनें।';
          case 'listen_select':
          case 'listen_comprehension':
            return _listenSelectQuestion.isNotEmpty ? _listenSelectQuestion : 'ऑडियो ध्यान से सुनें और सही उत्तर चुनें।';
          default:
            return 'दिए गए कार्य को पूरा करें।';
        }
      } else if (nLang == 'mr') {
        switch (stageType) {
          case 'word_match':
          case 'match_pairs':
            return 'जर्मन शब्द आणि त्याचा योग्य अर्थ टॅप करा.';
          case 'listen_tap':
            return 'ऑडिओ लक्षपूर्वक ऐका आणि ऐकलेले जर्मन शब्द निवडा.';
          case 'sentence_builder':
            return 'शब्दांना योग्य क्रमाने लावून जर्मन वाक्य बनवा.';
          case 'sprechen':
            return 'माइक टॅप करा आणि इकोसोबत जर्मनमध्ये बोला.';
          case 'cloze_test':
          case 'cloze':
            return 'वाक्य पूर्ण करण्यासाठी योग्य जर्मन शब्द निवडा.';
          case 'type_word':
          case 'type_input':
            return _typeHint.isNotEmpty ? _typeHint : 'रिकाम्या जागेसाठी योग्य जर्मन शब्द लिहा.';
          case 'dialogue_bubble':
          case 'dialogue':
            return 'संभाषण पुढे नेण्यासाठी सर्वात योग्य पर्याय निवडा.';
          case 'listen_select':
          case 'listen_comprehension':
            return _listenSelectQuestion.isNotEmpty ? _listenSelectQuestion : 'ऑडिओ लक्षपूर्वक ऐका आणि अचूक पर्याय निवडा.';
          default:
            return 'दिलेले कार्य पूर्ण करा.';
        }
      } else {
        switch (stageType) {
          case 'word_match':
          case 'match_pairs':
            return 'Tap a German greeting and its matching English meaning.';
          case 'listen_tap':
            return 'Listen to the audio and arrange the words in order.';
          case 'sentence_builder':
            return 'Arrange the words to form the correct German sentence.';
          case 'sprechen':
            return 'Tap the microphone and speak aloud to Echo the Dolphin.';
          case 'cloze_test':
          case 'cloze':
            return 'Tap the correct German word to complete the sentence.';
          case 'type_word':
          case 'type_input':
            return _typeHint.isNotEmpty ? _typeHint : 'Translate and spell the missing word correctly.';
          case 'dialogue_bubble':
          case 'dialogue':
            return 'Choose the most natural reply to continue the conversation.';
          case 'listen_select':
          case 'listen_comprehension':
            return _listenSelectQuestion.isNotEmpty ? _listenSelectQuestion : 'Listen carefully to the audio and select the right option.';
          default:
            return 'Complete the task.';
        }
      }
    }
  }

  String _getTypeWordPlaceholder() {
    final isEn = _isTargetEnglish;
    final nLang = _nativeLang;
    if (isEn) {
      if (nLang == 'hi') return 'यहाँ अंग्रेजी शब्द लिखें...';
      if (nLang == 'mr') return 'येथे इंग्रजी शब्द लिहा...';
      return 'Type English word here...';
    } else {
      if (nLang == 'hi') return 'यहाँ जर्मन शब्द लिखें...';
      if (nLang == 'mr') return 'येथे जर्मन शब्द लिहा...';
      return 'Type German word here...';
    }
  }

  String _getSprechenListeningText() {
    final isEn = _isTargetEnglish;
    final nLang = _nativeLang;
    if (isEn) {
      if (nLang == 'hi') return 'आपकी आवाज़ सुनी जा रही है...';
      if (nLang == 'mr') return 'तुमचा आवाज ऐकत आहे...';
      return 'Listening to your pronunciation...';
    } else {
      if (nLang == 'hi') return 'आपकी आवाज़ सुनी जा रही है...';
      if (nLang == 'mr') return 'तुमचा आवाज ऐकत आहे...';
      return 'Listening to your pronunciation...';
    }
  }

  String _getSprechenTapToSpeakText() {
    final isEn = _isTargetEnglish;
    final nLang = _nativeLang;
    if (isEn) {
      if (nLang == 'hi') return 'बोलने के लिए माइक दबाएं';
      if (nLang == 'mr') return 'बोलण्यासाठी माइक टॅप करा';
      return 'Tap Mic to Speak';
    } else {
      if (nLang == 'hi') return 'बोलने के लिए माइक दबाएं';
      if (nLang == 'mr') return 'बोलण्यासाठी माइक टॅप करा';
      return 'Tap Mic to Speak';
    }
  }

  String _getSprechenSkipText() {
    final isEn = _isTargetEnglish;
    final nLang = _nativeLang;
    if (isEn) {
      if (nLang == 'hi') return 'अभी बोल नहीं सकते';
      if (nLang == 'mr') return 'आता बोलू शकत नाही';
      return "CAN'T SPEAK RIGHT NOW";
    } else {
      return "CAN'T SPEAK RIGHT NOW";
    }
  }

  Widget _buildCurrentStageView() {
    if (_isCelebrationStage || _currentStage >= _activeStageTypes.length) {
      return _buildCelebrationStage();
    }

    final stageType = _activeStageTypes[_currentStage];
    switch (stageType) {
      case 'word_match':
      case 'match_pairs':
        return _buildWordMatchStage();
      case 'listen_tap':
        return _buildListeningStage();
      case 'cloze_test':
      case 'cloze':
        return _buildClozeStage();
      case 'sentence_builder':
        return _buildSentenceBuilderStage();
      case 'type_word':
      case 'type_input':
        return _buildTypeWordStage();
      case 'dialogue_bubble':
      case 'dialogue':
        return _buildDialogueBubbleStage();
      case 'listen_select':
      case 'listen_comprehension':
        return _buildListenSelectStage();
      case 'sprechen':
        if (ref.watch(speechPreferencesProvider).isCurrentlyMuted) {
          return _buildSnoozedSprechenStage();
        }
        return _buildSprechenStage();
      default:
        return _buildCelebrationStage();
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // STAGE 0: Match Word Pairs (Vocabulary basics)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildWordMatchStage() {
    return Column(
      key: const ValueKey('word_match'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStageTitle('word_match'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getStageSubtitle('word_match'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // German Column
                    Expanded(
                      child: Column(
                        children: _germanWords.map((word) {
                          final isMatched = _matchedGerman.contains(word);
                          final isSelected = _selectedGerman == word;
                          final isWrong = _wrongGermanWord == word;
                          final isCorrect = _correctGermanWord == word;
                          return _buildMatchTile(
                            text: word,
                            isSelected: isSelected,
                            isMatched: isMatched,
                            isWrong: isWrong,
                            isCorrect: isCorrect,
                            onTap: () => _onGermanMatchTap(word),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // English Column
                    Expanded(
                      child: Column(
                        children: _englishWords.map((word) {
                          final isMatched = _matchedEnglish.contains(word);
                          final isSelected = _selectedEnglish == word;
                          final isWrong = _wrongEnglishWord == word;
                          final isCorrect = _correctEnglishWord == word;
                          return _buildMatchTile(
                            text: word,
                            isSelected: isSelected,
                            isMatched: isMatched,
                            isWrong: isWrong,
                            isCorrect: isCorrect,
                            onTap: () => _onEnglishMatchTap(word),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Bottom Feedback Sheet when finished
        if (_matchFinished)
          DuoFeedbackSheet(
            isSuccess: true,
            title: _isTargetEnglish
                ? (_nativeLang == 'hi'
                    ? 'शानदार! सभी जोड़े मिल गए!'
                    : (_nativeLang == 'mr'
                        ? 'छान! सर्व जोड्या जुळल्या!'
                        : 'Well done! Perfect match!'))
                : 'Wunderbar! Perfect Match!',
            subtitle: _isTargetEnglish
                ? (_nativeLang == 'hi'
                    ? 'आपने सभी शब्द सफलतापूर्वक सीख लिए।'
                    : (_nativeLang == 'mr'
                        ? 'तुम्ही सर्व शब्द यशस्वीपणे शिकलात.'
                        : 'You mastered all the words.'))
                : 'You mastered the core German greetings.',
            buttonText: 'NEXT TASK →',
            onContinue: _nextStage,
          ),
      ],
    );
  }

  Widget _buildMatchTile({
    required String text,
    required bool isSelected,
    required bool isMatched,
    bool isWrong = false,
    bool isCorrect = false,
    required VoidCallback onTap,
  }) {
    Color bg;
    Color border;
    double borderWidth;
    Color textColor;
    List<BoxShadow>? boxShadow;

    if (isWrong) {
      // Wrong Mismatch: Flashes Soft Red (#FEF2F2, border #EF4444, 2.5px width)
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFEF4444);
      borderWidth = 2.5;
      textColor = const Color(0xFFEF4444);
      boxShadow = const [
        BoxShadow(
          color: Color(0xFFDC2626),
          offset: Offset(0, 3.5),
          blurRadius: 0,
        ),
      ];
    } else if (isCorrect) {
      // Correct Match: Flashes Emerald Green (#ECFDF5, border #10B981, shadow #059669)
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFF10B981);
      borderWidth = 2.5;
      textColor = const Color(0xFF059669);
      boxShadow = const [
        BoxShadow(
          color: Color(0xFF059669),
          offset: Offset(0, 3.5),
          blurRadius: 0,
        ),
      ];
    } else if (isMatched) {
      // Completed state: Smoothly transitions to completed state
      bg = const Color(0xFFF1F5F9);
      border = const Color(0xFFCBD5E1);
      borderWidth = 1.5;
      textColor = const Color(0xFF94A3B8);
      boxShadow = null;
    } else if (isSelected) {
      // Selected: Blue 3D border (#0284C7), soft blue background (#F0F9FF), bottom shadow (#0369A1)
      bg = const Color(0xFFF0F9FF);
      border = const Color(0xFF0284C7);
      borderWidth = 2.5;
      textColor = const Color(0xFF0284C7);
      boxShadow = const [
        BoxShadow(
          color: Color(0xFF0369A1),
          offset: Offset(0, 3.5),
          blurRadius: 0,
        ),
      ];
    } else {
      // Default: Solid 3.5px physical bevel BoxShadow(color: Color(0xFFCBD5E1), offset: Offset(0, 3.5), blurRadius: 0), white background, rounded 16px
      bg = Colors.white;
      border = const Color(0xFFE2E8F0);
      borderWidth = 1.5;
      textColor = const Color(0xFF1E293B);
      boxShadow = const [
        BoxShadow(
          color: Color(0xFFCBD5E1),
          offset: Offset(0, 3.5),
          blurRadius: 0,
        ),
      ];
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _MatchTileShake(
        shake: isWrong,
        duration: const Duration(milliseconds: 250),
        child: GestureDetector(
          onTap: (isMatched || isCorrect || isWrong) ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: double.infinity,
            height: 60,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border, width: borderWidth),
              boxShadow: boxShadow,
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // STAGE 1: Listening & Karaoke Rhythm
  // ══════════════════════════════════════════════════════════════════
  Widget _buildListeningStage() {
    return Column(
      key: const ValueKey('listen_tap'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStageTitle('listen_tap'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getStageSubtitle('listen_tap'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),

                // Center Stage: Dolphin Mascot + Speaker Buttons (Normal & Turtle)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDolphinMascot(
                      size: 110,
                      pose: MascotPose.headphones,
                      isListening: _isPlayingAudio,
                    ),
                    const SizedBox(width: 16),
                    // Normal Speed Play Button
                    GestureDetector(
                      onTap: () => _playListenAudio(speed: 1.0),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFF0369A1),
                              blurRadius: 0,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Slow (Turtle) Play Button
                    GestureDetector(
                      onTap: () => _playListenAudio(speed: 0.75),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF1F5F9),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0xFFCBD5E1),
                              blurRadius: 0,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('🐢', style: TextStyle(fontSize: 24)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Assembly Area
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 80),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _listenSelectedIndices.map((bankIndex) {
                      final word = _listenBank[bankIndex];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _listenSelectedIndices.remove(bankIndex);
                            _listenCorrect = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                          ),
                          child: Text(
                            word,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 28),

                // Bank Tiles
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _listenBank.asMap().entries.map((entry) {
                    final index = entry.key;
                    final word = entry.value;
                    final isUsed = _listenSelectedIndices.contains(index);
                    return GestureDetector(
                      onTap: isUsed
                          ? null
                          : () {
                              TtsService().speakWord(word);
                              setState(() {
                                _listenSelectedIndices.add(index);
                                _listenCorrect = null;
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUsed ? const Color(0xFFF1F5F9) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isUsed ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                          boxShadow: isUsed
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0xFFE2E8F0),
                                    blurRadius: 0,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Text(
                          word,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isUsed ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        // Check or feedback
        if (_listenCorrect == null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: TactileGameButton(
              text: 'CHECK ANSWER',
              variant: GameButtonVariant.success,
              height: 52,
              onPressed: _listenSelectedIndices.isEmpty
                  ? null
                  : () {
                      final selectedWords = _listenSelected;
                      final selectedClean = selectedWords.join(' ').toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
                      final targetClean = _listenTarget.join(' ').toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
                      final isMatch = selectedClean == targetClean || selectedWords.join(' ') == _listenTarget.join(' ');
                      setState(() => _listenCorrect = isMatch);
                      _triggerPrewarmForNext();
                      if (!isMatch) {
                        _handleIncorrectAnswer();
                      }
                    },
            ),
          )
        else
          DuoFeedbackSheet(
            isSuccess: _listenCorrect == true,
            title: _listenCorrect == true
                ? (_isTargetEnglish
                    ? (_nativeLang == 'hi'
                        ? 'बहुत खूब! बिल्कुल सही वाक्य!'
                        : (_nativeLang == 'mr'
                            ? 'उत्तम! अगदी अचूक वाक्य!'
                            : 'Great job! Correct sequence!'))
                    : 'Sehr gut! Correct sequence!')
                : 'Almost there!',
            subtitle: 'Target: "${_listenTargetSentence.isNotEmpty ? _listenTargetSentence : _listenTarget.join(' ')}"',
            buttonText: 'NEXT TASK →',
            onContinue: _nextStage,
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // STAGE: Cloze Test (Fill in the Blank)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildClozeStage() {
    final parts = _clozeSentence.split(RegExp(r'_+'));
    final before = parts.isNotEmpty ? parts[0] : '';
    final after = parts.length > 1 ? parts.sublist(1).join('') : '';

    return Column(
      key: const ValueKey('cloze_test'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStageTitle('cloze_test'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getStageSubtitle('cloze_test'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),

                // Sentence Card with underlined blank
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFE2E8F0),
                        blurRadius: 0,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF0284C7), size: 28),
                            onPressed: () {
                              final fullSentence = _clozeSelectedOption != null
                                  ? _clozeSentence.replaceAll(RegExp(r'_+'), _clozeSelectedOption!)
                                  : _clozeSentence.replaceAll(RegExp(r'_+'), _clozeBlank);
                              TtsService().speakSentence(fullSentence);
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 8,
                              children: [
                                if (before.trim().isNotEmpty)
                                  Text(
                                    before.trim(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                                // Blank pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _clozeSelectedOption != null
                                        ? (_clozeCorrect == true
                                            ? const Color(0xFFDCFCE7)
                                            : (_clozeCorrect == false
                                                ? const Color(0xFFFEE2E2)
                                                : const Color(0xFFE0F2FE)))
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _clozeSelectedOption != null
                                          ? (_clozeCorrect == true
                                              ? const Color(0xFF10B981)
                                              : (_clozeCorrect == false
                                                  ? const Color(0xFFEF4444)
                                                  : const Color(0xFF0284C7)))
                                          : const Color(0xFF94A3B8),
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    _clozeSelectedOption ?? '_______',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: _clozeSelectedOption != null
                                          ? (_clozeCorrect == true
                                              ? const Color(0xFF15803D)
                                              : (_clozeCorrect == false
                                                  ? const Color(0xFFDC2626)
                                                  : const Color(0xFF0284C7)))
                                          : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                ),
                                if (after.trim().isNotEmpty)
                                  Text(
                                    after.trim(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF1E293B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (_clozeTranslation.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        const SizedBox(height: 10),
                        Text(
                          _clozeTranslation,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  'CHOOSE THE CORRECT WORD:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),

                // Option chips
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: _clozeOptions.map((opt) {
                    final isSelected = _clozeSelectedOption == opt;
                    return GestureDetector(
                      onTap: () => _onClozeOptionTap(opt),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE0F2FE) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                            width: isSelected ? 2.0 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
                              blurRadius: 0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.volume_up_outlined, size: 18, color: Color(0xFF0284C7)),
                            const SizedBox(width: 8),
                            Text(
                              opt,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        // Bottom Action Bar
        if (_clozeCorrect == null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: TactileGameButton(
              text: 'CHECK ANSWER',
              variant: GameButtonVariant.success,
              height: 52,
              onPressed: _clozeSelectedOption == null ? null : _evaluateCloze,
            ),
          )
        else
          DuoFeedbackSheet(
            isSuccess: _clozeCorrect == true,
            title: _clozeCorrect == true
                ? (_isTargetEnglish
                    ? (_nativeLang == 'hi'
                        ? 'शाबाश! सही शब्द चुना!'
                        : (_nativeLang == 'mr'
                            ? 'शाब्बास! अचूक शब्द निवडला!'
                            : 'Great job! Correct word!'))
                    : 'Hervorragend! Correct word!')
                : 'Not quite right!',
            subtitle: 'Complete: "${_clozeSentence.replaceAll(RegExp(r'_+'), _clozeBlank)}"',
            buttonText: 'CONTINUE →',
            onContinue: _nextStage,
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // STAGE 2: Sentence Builder
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSentenceBuilderStage() {
    return Column(
      key: const ValueKey('sentence_builder'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStageTitle('sentence_builder'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getStageSubtitle('sentence_builder'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 16),

                // English Prompt Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    boxShadow: const [
                      BoxShadow(color: Color(0xFFE2E8F0), blurRadius: 0, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF0284C7), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _sentencePrompt,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Assembled Slots
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 80),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _builderSelectedIndices.map((bankIndex) {
                      final word = _builderBank[bankIndex];
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _builderSelectedIndices.remove(bankIndex);
                            _builderCorrect = null;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
                          ),
                          child: Text(
                            word,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0284C7),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Bank Tiles
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _builderBank.asMap().entries.map((entry) {
                    final index = entry.key;
                    final word = entry.value;
                    final isUsed = _builderSelectedIndices.contains(index);
                    return GestureDetector(
                      onTap: isUsed
                          ? null
                          : () {
                              TtsService().speakWord(word);
                              setState(() {
                                _builderSelectedIndices.add(index);
                                _builderCorrect = null;
                              });
                            },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUsed ? const Color(0xFFF1F5F9) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isUsed ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                          boxShadow: isUsed
                              ? null
                              : const [
                                  BoxShadow(
                                    color: Color(0xFFE2E8F0),
                                    blurRadius: 0,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Text(
                          word,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isUsed ? const Color(0xFFCBD5E1) : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        if (_builderCorrect == null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: TactileGameButton(
              text: 'VERIFY SENTENCE',
              variant: GameButtonVariant.success,
              height: 52,
              onPressed: _builderSelectedIndices.isEmpty
                  ? null
                  : () {
                      final selectedWords = _builderSelected;
                      final selClean = selectedWords.join(' ').toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
                      final tgtClean = _builderTarget.join(' ').toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
                      final isMatch = selClean == tgtClean || selectedWords.join(' ') == _builderTarget.join(' ');
                      setState(() => _builderCorrect = isMatch);
                      _triggerPrewarmForNext();
                      if (!isMatch) {
                        _handleIncorrectAnswer();
                      }
                    },
            ),
          )
        else
          DuoFeedbackSheet(
            isSuccess: _builderCorrect == true,
            title: _builderCorrect == true
                ? (_isTargetEnglish
                    ? (_nativeLang == 'hi'
                        ? 'शानदार! बिल्कुल सही वाक्य बनाया!'
                        : (_nativeLang == 'mr'
                            ? 'छान! अगदी अचूक वाक्य बनवले!'
                            : 'Outstanding! Great job!'))
                    : 'Hervorragend! Outstanding!')
                : 'Check punctuation and order',
            subtitle: '${_isTargetEnglish ? "Target" : "German"}: "${_builderTargetSentence.isNotEmpty ? _builderTargetSentence : _builderTarget.join(' ')}"',
            buttonText: 'NEXT TASK →',
            onContinue: _nextStage,
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // STAGE: Type Word (German Spelling with Quick Umlaut Buttons)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildTypeWordStage() {
    return Column(
      key: const ValueKey('type_word'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStageTitle('type_word'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getStageSubtitle('type_word'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),

                // Prompt Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFE2E8F0),
                        blurRadius: 0,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF0284C7), size: 26),
                            onPressed: () {
                              final textToSpeak = _typePrompt.replaceAll(RegExp(r'_+'), _typeTarget);
                              TtsService().speakSentence(textToSpeak);
                            },
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _typePrompt,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_typeTranslation.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          _typeTranslation,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Text Input Field
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _typeCorrect == true
                          ? const Color(0xFF10B981)
                          : (_typeCorrect == false ? const Color(0xFFEF4444) : const Color(0xFF0284C7)),
                      width: 2.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFE2E8F0),
                        blurRadius: 0,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _typeWordController,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                          decoration: InputDecoration(
                            hintText: _getTypeWordPlaceholder(),
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              color: const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (_) {
                            setState(() {
                              _typeCorrect = null;
                            });
                          },
                          onSubmitted: (_) => _evaluateTypeWord(),
                        ),
                      ),
                      if (_typeWordController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 20),
                          onPressed: () {
                            _typeWordController.clear();
                            setState(() => _typeCorrect = null);
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // German Umlauts Quick-Tap Bar (Only shown when learning German)
                if (!_isTargetEnglish) ...[
                  Text(
                    'QUICK GERMAN UMLAUTS:',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['ä', 'ö', 'ü', 'ß', 'Ä', 'Ö', 'Ü'].map((umlaut) {
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            onTap: () => _addUmlautToInput(umlaut),
                            child: Container(
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFFE2E8F0),
                                    blurRadius: 0,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                umlaut,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Bottom Action Bar
        if (_typeCorrect == null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: TactileGameButton(
              text: 'CHECK SPELLING',
              variant: GameButtonVariant.success,
              height: 52,
              onPressed: _typeWordController.text.trim().isEmpty ? null : _evaluateTypeWord,
            ),
          )
        else
          DuoFeedbackSheet(
            isSuccess: _typeCorrect == true,
            title: _typeCorrect == true
                ? (_isTargetEnglish
                    ? (_nativeLang == 'hi'
                        ? 'बिल्कुल सही स्पेलिंग!'
                        : (_nativeLang == 'mr'
                            ? 'अगदी अचूक स्पेलिंग!'
                            : 'Excellent! Perfect spelling!'))
                    : 'Ausgezeichnet! Perfect German spelling!')
                : 'Check the spelling!',
            subtitle: 'Target: "$_typeTarget"',
            buttonText: 'CONTINUE →',
            onContinue: _nextStage,
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // STAGE: Dialogue Bubble (Conversational Chat Messenger)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildDialogueBubbleStage() {
    return Column(
      key: const ValueKey('dialogue_bubble'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStageTitle('dialogue_bubble'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getStageSubtitle('dialogue_bubble'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),

                // Chat Messages Container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      // Partner Bubble (Left)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: const Color(0xFF0284C7),
                            child: Text(
                              _dialoguePartnerName.isNotEmpty ? _dialoguePartnerName[0] : 'F',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _dialoguePartnerName,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topRight: Radius.circular(16),
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0xFFE2E8F0),
                                        blurRadius: 0,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF0284C7), size: 24),
                                        onPressed: () => TtsService().speakSentence(_dialoguePartnerMessage),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _dialoguePartnerMessage,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF1E293B),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_dialoguePartnerTranslation.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Text(
                                      _dialoguePartnerTranslation,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // User Reply Bubble (Right)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                gradient: _dialogueSelectedIdx != null
                                    ? const LinearGradient(
                                        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                                      )
                                    : null,
                                color: _dialogueSelectedIdx == null ? Colors.white : null,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  bottomLeft: Radius.circular(16),
                                  bottomRight: Radius.circular(16),
                                ),
                                border: _dialogueSelectedIdx == null
                                    ? Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid)
                                    : null,
                              ),
                              child: Text(
                                _dialogueSelectedIdx != null
                                    ? (_dialogueOptions[_dialogueSelectedIdx!]['text'] ?? '')
                                    : 'Tap your reply below...',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _dialogueSelectedIdx != null ? Colors.white : const Color(0xFF94A3B8),
                                  fontStyle: _dialogueSelectedIdx == null ? FontStyle.italic : FontStyle.normal,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(0xFF10B981),
                            child: Icon(Icons.person, color: Colors.white, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'CHOOSE YOUR REPLY:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),

                // Reply Option Cards
                ..._dialogueOptions.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final opt = entry.value;
                  final text = (opt['text'] ?? '').toString();
                  final isSelected = _dialogueSelectedIdx == idx;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () => _onDialogueOptionTap(idx),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE0F2FE) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                            width: isSelected ? 2.0 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
                              blurRadius: 0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFF1F5F9),
                              ),
                              child: Text(
                                '${idx + 1}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                text,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            const Icon(Icons.volume_up_outlined, size: 20, color: Color(0xFF0284C7)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Bottom Action Bar
        if (_dialogueCorrect == null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: TactileGameButton(
              text: 'SEND REPLY',
              variant: GameButtonVariant.success,
              height: 52,
              onPressed: _dialogueSelectedIdx == null ? null : _evaluateDialogue,
            ),
          )
        else
          DuoFeedbackSheet(
            isSuccess: _dialogueCorrect == true,
            title: _dialogueCorrect == true
                ? (_isTargetEnglish
                    ? (_nativeLang == 'hi'
                        ? 'शानदार! बेहतरीन बातचीत!'
                        : (_nativeLang == 'mr'
                            ? 'अप्रतिम! उत्कृष्ट संभाषण!'
                            : 'Perfect! Great conversation!'))
                    : 'Perfekt! Great conversational choice!')
                : 'Try a different reply!',
            subtitle: 'You continued the conversation with $_dialoguePartnerName!',
            buttonText: 'CONTINUE →',
            onContinue: _nextStage,
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // STAGE: Listen Select (Comprehension MCQ)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildListenSelectStage() {
    return Column(
      key: const ValueKey('listen_select'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStageTitle('listen_select'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getStageSubtitle('listen_select'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),

                // Audio Mascot Player Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xFFE2E8F0),
                        blurRadius: 0,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Normal Speed Play Button
                          GestureDetector(
                            onTap: () => _playListenSelectAudio(speed: 1.0),
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF0284C7),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF0369A1),
                                    blurRadius: 0,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 38),
                            ),
                          ),
                          const SizedBox(width: 20),
                          // Slow (Turtle) Play Button
                          GestureDetector(
                            onTap: () => _playListenSelectAudio(speed: 0.75),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFF1F5F9),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFFCBD5E1),
                                    blurRadius: 0,
                                    offset: Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text('🐢', style: TextStyle(fontSize: 24)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Tap speaker to listen',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                Text(
                  'SELECT THE MATCHING MEANING:',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF94A3B8),
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 12),

                // Option Cards
                ..._listenSelectOptions.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final opt = entry.value;
                  final text = (opt['text'] ?? '').toString();
                  final isSelected = _listenSelectSelectedIdx == idx;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () => _onListenSelectOptionTap(idx),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE0F2FE) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
                            width: isSelected ? 2.0 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
                              blurRadius: 0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                                  width: 2,
                                ),
                                color: isSelected ? const Color(0xFF0284C7) : Colors.transparent,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                text,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),

        // Bottom Action Bar
        if (_listenSelectCorrect == null)
          Padding(
            padding: const EdgeInsets.all(20),
            child: TactileGameButton(
              text: 'CHECK ANSWER',
              variant: GameButtonVariant.success,
              height: 52,
              onPressed: _listenSelectSelectedIdx == null ? null : _evaluateListenSelect,
            ),
          )
        else
          DuoFeedbackSheet(
            isSuccess: _listenSelectCorrect == true,
            title: _listenSelectCorrect == true
                ? (_isTargetEnglish
                    ? (_nativeLang == 'hi'
                        ? 'बहुत खूब! सही समझा!'
                        : (_nativeLang == 'mr'
                            ? 'छान! अचूक समजले!'
                            : 'Great job! Correct comprehension!'))
                    : 'Hervorragend! Correct comprehension!')
                : 'Almost there!',
            subtitle: 'Sentence heard: "$_listenSelectSentence"',
            buttonText: 'CONTINUE →',
            onContinue: _nextStage,
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // STAGE 3: Sprechen Speech Pronunciation & Lip-Sync Karaoke
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSprechenStage() {
    return Column(
      key: const ValueKey('sprechen'),
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStageTitle('sprechen'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getStageSubtitle('sprechen'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 24),

                // Mascot & German Prompt Bubble with Real-Time Lip-Sync Highlighting
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (!_isSprechenDemoPlaying) _playSprechenDemo();
                      },
                      child: AnimatedDolphinMascot(
                        size: 95,
                        pose: _speechPassed == true
                            ? MascotPose.celebrate
                            : (_isSpeaking
                                ? MascotPose.thinking
                                : (_isSprechenDemoPlaying ? MascotPose.jump : null)),
                        isListening: _isSpeaking,
                        isCelebrating: _speechPassed == true,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isSprechenDemoPlaying
                                ? const Color(0xFF0284C7)
                                : const Color(0xFF0284C7),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _isSprechenDemoPlaying
                                  ? const Color(0xFF7DD3FC)
                                  : const Color(0xFFBAE6FD),
                              blurRadius: 0,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_isSprechenDemoPlaying)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0284C7),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _isTargetEnglish
                                          ? (_nativeLang == 'hi'
                                              ? 'इको बोल रहा है...'
                                              : (_nativeLang == 'mr'
                                                  ? 'इको बोलत आहे...'
                                                  : 'Echo is speaking...'))
                                          : 'Echo is speaking...',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0284C7),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    if (!_isSprechenDemoPlaying) _playSprechenDemo();
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.volume_up_rounded, size: 14, color: Color(0xFF0284C7)),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isTargetEnglish
                                            ? (_nativeLang == 'hi'
                                                ? 'इको को सुनें (सुनने के लिए छुएं)'
                                                : (_nativeLang == 'mr'
                                                    ? 'इकोला ऐका (ऐकण्यासाठी टॅप करा)'
                                                    : 'Listen to Echo (Tap to hear)'))
                                            : 'Listen to Echo (Tap to hear)',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0284C7),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _sprechenKaraokeWords.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final w = entry.value;

                                // End-of-Sentence Evaluation Scorecard:
                                // Words remain calm and stationary while machine or student speaks.
                                // Green and Orange feedback pills appear ONLY after the student finishes speaking!
                                final isGraded = _speechPassed != null;
                                final token = (idx < _evaluatedTokens.length) ? _evaluatedTokens[idx] : null;
                                final isPronounced = token != null ? token.isPassed : false;
                                final isMissed = isGraded && !isPronounced;

                                Color bgColor = Colors.transparent;
                                Color textColor = const Color(0xFF0284C7);
                                Border? border;
                                List<BoxShadow>? shadows;

                                if (isGraded) {
                                  if (isPronounced) {
                                    // Student successfully pronounced word (Emerald Green Pill)
                                    bgColor = const Color(0xFFECFDF5);
                                    textColor = const Color(0xFF047857);
                                    border = Border.all(color: const Color(0xFF10B981), width: 1.5);
                                    shadows = [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ];
                                  } else {
                                    // Student missed or mispronounced word (Amber/Orange Pill)
                                    bgColor = const Color(0xFFFFF7ED);
                                    textColor = const Color(0xFFC2410C);
                                    border = Border.all(color: const Color(0xFFF97316), width: 1.5);
                                    shadows = [
                                      BoxShadow(
                                        color: const Color(0xFFF97316).withValues(alpha: 0.15),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ];
                                  }
                                } else {
                                  textColor = const Color(0xFF0284C7);
                                }

                                return GestureDetector(
                                  onTap: () => TtsService().speakWord(w.word),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isGraded ? 8 : 4,
                                      vertical: isGraded ? 4 : 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: border,
                                      boxShadow: shadows,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          w.word,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: textColor,
                                          ),
                                        ),
                                        if (isGraded && isPronounced) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.check_rounded, color: Color(0xFF10B981), size: 15),
                                        ] else if (isGraded && isMissed) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.volume_up_rounded, color: Color(0xFFF97316), size: 14),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _sprechenTranslation.isNotEmpty
                                  ? _sprechenTranslation
                                  : 'Hello! How are you?',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 36),

                // Large Tactile Microphone Button (from 062815a)
                Center(
                  child: GestureDetector(
                    onTap: _toggleSpeaking,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isSpeaking
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF0284C7),
                        boxShadow: [
                          BoxShadow(
                            color: _isSpeaking
                                ? const Color(0x66EF4444)
                                : const Color(0xFF0369A1),
                            blurRadius: _isSpeaking ? 16 : 0,
                            offset: _isSpeaking
                                ? const Offset(0, 4)
                                : const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _isSpeaking
                              ? Icons.mic_rounded
                              : Icons.mic_none_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _isSpeaking
                        ? _getSprechenListeningText()
                        : _getSprechenTapToSpeakText(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _isSpeaking
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),

                if (_spokenText.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  if (_speechPassed == true)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF86EFAC), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded,
                              color: Color(0xFF15803D), size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Recognized $_speechAccuracy%: "$_spokenText"',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFFCA5A5), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: Color(0xFFDC2626), size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Match $_speechAccuracy%: "$_spokenText"',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isTargetEnglish
                                      ? (_nativeLang == 'hi'
                                          ? 'नारंगी शब्दों पर टैप करके सही उच्चारण सुनें, फिर पुनः प्रयास करें!'
                                          : (_nativeLang == 'mr'
                                              ? 'नारंगी शब्दांवर टॅप करून योग्य उच्चार ऐका, नंतर पुन्हा प्रयत्न करा!'
                                              : 'Tap orange words to hear pronunciation, then try again!'))
                                      : 'Tap orange words to hear pronunciation, then try again!',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFC2410C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await ref
                          .read(speechPreferencesProvider.notifier)
                          .snoozeSpeakingExercises(
                            duration: const Duration(hours: 1),
                          );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              _isTargetEnglish
                                  ? (_nativeLang == 'hi'
                                      ? 'बोलने के अभ्यास 1 घंटे के लिए बंद कर दिए गए हैं।'
                                      : (_nativeLang == 'mr'
                                          ? 'बोलण्याचे सराव 1 तासासाठी बंद केले आहेत.'
                                          : 'Speaking exercises snoozed for 1 hour.'))
                                  : 'Speaking exercises snoozed for 1 hour.',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            duration: const Duration(seconds: 3),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        _nextStage();
                      }
                    },
                    icon: const Icon(Icons.volume_off_rounded,
                        size: 16, color: Color(0xFF94A3B8)),
                    label: Text(
                      _getSprechenSkipText(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (_speechPassed == true)
          DuoFeedbackSheet(
            isSuccess: true,
            title: _isTargetEnglish
                ? (_nativeLang == 'hi'
                    ? 'शानदार उच्चारण!'
                    : (_nativeLang == 'mr'
                        ? 'उत्कृष्ट उच्चार!'
                        : 'Native-Level Pronunciation!'))
                : 'Native-Level Pronunciation!',
            subtitle: _isTargetEnglish
                ? (_nativeLang == 'hi'
                    ? 'इको को आपके उच्चारण पर गर्व है! ($_speechAccuracy% मैच)'
                    : (_nativeLang == 'mr'
                        ? 'इकोला तुमच्या इंग्रजी उच्चाराचा अभिमान आहे! ($_speechAccuracy% मॅच)'
                        : 'Echo is proud of your English accent! ($_speechAccuracy% match)'))
                : 'Echo is proud of your German accent! ($_speechAccuracy% match)',
            buttonText: 'SEE RESULTS 🎉',
            onContinue: _nextStage,
          ),
      ],
    );
  }

  Widget _buildSnoozedSprechenStage() {
    return Column(
      key: const ValueKey('sprechen_snoozed'),
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFFE2E8F0),
                      blurRadius: 0,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.volume_off_rounded,
                        color: Color(0xFF64748B),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Speaking Exercises Paused',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Speaking challenges are snoozed for 1 hour. You can resume them anytime or continue with the lesson.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await ref
                                  .read(speechPreferencesProvider.notifier)
                                  .unmuteSpeakingExercises();
                              if (mounted) setState(() {});
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Color(0xFF0284C7), width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Resume Speaking',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _nextStage,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text(
                              'Continue',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // STAGE 4: Dopamine Celebration & Rewards
  // ══════════════════════════════════════════════════════════════════
  Widget _buildCelebrationStage() {
    final xp = _earnedXp;
    final accuracy = _calculatedAccuracy;
    final lessonTitle = (widget.node?.title != null && widget.node!.title.isNotEmpty)
        ? widget.node!.title
        : 'this lesson';

    return Padding(
      key: const ValueKey('celebration'),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          const Spacer(),

          // Celebratory Dolphin
          const AnimatedDolphinMascot(
            size: 190,
            pose: MascotPose.celebrate,
          ),
          const SizedBox(height: 24),

          Text(
            'LESSON COMPLETE!',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: const Color(0xFFF59E0B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You mastered "$lessonTitle" with flying colors!',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 36),

          // 3 Metric Cards
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  label: 'TOTAL XP',
                  value: '+$xp',
                  color: const Color(0xFFF59E0B),
                  icon: Icons.bolt_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  label: 'ACCURACY',
                  value: '$accuracy%',
                  color: const Color(0xFF10B981),
                  icon: Icons.track_changes_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  label: 'TIME',
                  value: '1:24',
                  color: const Color(0xFF0284C7),
                  icon: Icons.timer_outlined,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Duolingo-styled 2X Bonus XP Rewarded Ad Option
          if (!_hasClaimedDoubleXp) ...[
            TactileGameButton(
              text: '🎬 2X BONUS XP (Watch Video)',
              icon: Icons.bolt_rounded,
              variant: GameButtonVariant.secondary,
              height: 52,
              fontSize: 15,
              isLoading: _isLoadingDoubleXpAd,
              onPressed: _isLoadingDoubleXpAd ? null : _claimDoubleXpReward,
            ),
            const SizedBox(height: 12),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '2X XP CLAIMED! (+${_earnedXp * 2} XP)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
          ],

          TactileGameButton(
            text: 'CONTINUE TO MAP',
            variant: GameButtonVariant.success,
            height: 56,
            fontSize: 16,
            onPressed: _finishLesson,
          ),
        ],
      ),
    );
  }

  void _claimDoubleXpReward() {
    setState(() => _isLoadingDoubleXpAd = true);
    final bonusXp = _earnedXp;

    AdService().showRewardedAd(
      onUserEarnedReward: () async {
        if (!mounted) return;
        setState(() {
          _isLoadingDoubleXpAd = false;
          _hasClaimedDoubleXp = true;
        });
        await ref.read(gamificationStatusProvider.notifier).claimAdReward('double_xp', bonusXp);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 2X Double XP activated! (+$bonusXp XP bonus!)'),
            backgroundColor: const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      onAdFailed: (error) {
        if (!mounted) return;
        setState(() => _isLoadingDoubleXpAd = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
        );
      },
      onAdDismissed: (_) {
        if (mounted) setState(() => _isLoadingDoubleXpAd = false);
      },
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFE2E8F0),
            blurRadius: 0,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Subtle 250ms horizontal shake animation for word mismatch feedback
class _MatchTileShake extends StatefulWidget {
  final Widget child;
  final bool shake;
  final Duration duration;

  const _MatchTileShake({
    required this.child,
    required this.shake,
    this.duration = const Duration(milliseconds: 250),
  });

  @override
  State<_MatchTileShake> createState() => _MatchTileShakeState();
}

class _MatchTileShakeState extends State<_MatchTileShake> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _offsetAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: -4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4.0, end: 4.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.shake) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void didUpdateWidget(covariant _MatchTileShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shake && !oldWidget.shake) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _offsetAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_offsetAnimation.value, 0),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
