import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/animated_dolphin_mascot.dart';
import '../../../shared/widgets/tactile_game_button.dart';
import '../../../shared/widgets/duo_feedback_sheet.dart';
import '../../notes/data/models/karaoke_model.dart';
import '../data/models/gamification_models.dart';
import '../providers/gamification_provider.dart';
import '../../../core/services/tts_service.dart';

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

class _LessonSessionScreenState extends ConsumerState<LessonSessionScreen> {
  int _currentStage = 0;
  List<String> _activeStageTypes = [];
  int get _totalStages => _activeStageTypes.length;
  bool get _isCelebrationStage => _currentStage >= _totalStages;

  late final AudioPlayer _audioPlayer;
  StreamSubscription? _playerCompleteSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;

  bool _isPlayingAudio = false;
  String _preparedAudioUrl = '';

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
  bool _matchFinished = false;

  // ── Stage 1: Listening Data ───────────────────────────────────────
  String _listenTargetSentence = 'Guten Tag, ich bin Anna';
  List<String> _listenBank = ['Kaffee', 'Guten', 'Tag,', 'ich', 'bin', 'Anna'];
  List<String> _listenTarget = ['Guten', 'Tag,', 'ich', 'bin', 'Anna'];
  final List<String> _listenSelected = [];
  bool? _listenCorrect;
  String _listenAudioUrl = '';

  // ── Stage 2: Sentence Builder Data ────────────────────────────────
  String _sentencePrompt = 'Translate: "Good morning, how are you?"';
  String _builderTargetSentence = 'Guten Morgen, wie geht es dir?';
  List<String> _builderBank = ['Guten', 'Morgen,', 'wie', 'geht', 'es', 'dir?', 'schlafe', 'Kalt'];
  List<String> _builderTarget = ['Guten', 'Morgen,', 'wie', 'geht', 'es', 'dir?'];
  final List<String> _builderSelected = [];
  bool? _builderCorrect;

  // ── Stage 3: Sprechen Voice & Lip-Sync Karaoke Data ───────────────
  String _sprechenPrompt = 'Guten Tag! Wie geht es dir?';
  String _sprechenTranslation = 'Hello! How are you?';
  String _sprechenAudioUrl = '';
  List<KaraokeWord> _sprechenKaraokeWords = [];
  int _sprechenMinAccuracy = 75;
  bool _hasPlayedSprechenDemo = false;
  bool _isSprechenDemoPlaying = false;
  int _activeSprechenWordIndex = -1;
  Timer? _sprechenAutoPlayTimer;
  Timer? _ttsHighlightTimer;

  late final stt.SpeechToText _speech;
  bool _speechInitialized = false;
  bool _isSpeaking = false;
  bool? _speechPassed;
  String _spokenText = '';
  int _speechAccuracy = 0;
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
    _speech = stt.SpeechToText();
    _audioPlayer = AudioPlayer();
    TtsService().warmUp();

    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _isSprechenDemoPlaying = false;
          _activeSprechenWordIndex = -1;
        });
      }
    });

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = (state == PlayerState.playing);
          if (state != PlayerState.playing) {
            _isSprechenDemoPlaying = false;
            _activeSprechenWordIndex = -1;
          }
        });
      }
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((pos) {
      if (!mounted) return;
      final currentType = (!_isCelebrationStage && _currentStage < _activeStageTypes.length)
          ? _activeStageTypes[_currentStage]
          : null;
      if (currentType == 'sprechen' && _isSprechenDemoPlaying && _sprechenKaraokeWords.isNotEmpty) {
        final sec = pos.inMilliseconds / 1000.0;
        int activeIdx = -1;
        for (int i = 0; i < _sprechenKaraokeWords.length; i++) {
          final w = _sprechenKaraokeWords[i];
          if (sec >= w.start && sec <= w.end) {
            activeIdx = i;
            break;
          }
        }
        if (activeIdx != _activeSprechenWordIndex) {
          setState(() {
            _activeSprechenWordIndex = activeIdx;
          });
        }
      }
    });

    _initStagesData();

    if (_activeStageTypes.isNotEmpty) {
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
  }

  @override
  void dispose() {
    _ttsHighlightTimer?.cancel();
    _sprechenAutoPlayTimer?.cancel();
    _silenceTimer?.cancel();
    _playerCompleteSub?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    try {
      _speech.stop();
    } catch (_) {}
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

  Future<void> _playListenAudio() async {
    final rawUrl = _listenAudioUrl.trim();
    final url = _resolveAudioUrl(rawUrl);

    if (url.isNotEmpty) {
      try {
        if (!mounted) return;
        debugPrint('🔊 [_playListenAudio] Playing studio audio: $url');
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(url));
        _preparedAudioUrl = url;
        if (mounted) setState(() => _isPlayingAudio = true);
        return;
      } catch (e) {
        debugPrint('⚠️ [_playListenAudio] Audio playback error: $e, falling back to TTS');
      }
    }

    // Smart Hybrid Fallback: Native German TTS for this specific lesson!
    if (_listenTargetSentence.isNotEmpty) {
      debugPrint('🔊 [_playListenAudio] Smart Hybrid TTS speaking: $_listenTargetSentence');
      if (mounted) setState(() => _isPlayingAudio = true);
      await TtsService().speakSentence(_listenTargetSentence);
      if (mounted) setState(() => _isPlayingAudio = false);
    }
  }

  Future<void> _playListenSelectAudio({double speed = 1.0}) async {
    final rawUrl = _listenSelectAudioUrl.trim();
    final url = _resolveAudioUrl(rawUrl);

    if (url.isNotEmpty) {
      try {
        if (!mounted) return;
        debugPrint('🔊 [_playListenSelectAudio] Playing studio audio: $url (speed: $speed)');
        await _audioPlayer.stop();
        await _audioPlayer.setPlaybackRate(speed);
        await _audioPlayer.play(UrlSource(url));
        if (mounted) setState(() => _isPlayingAudio = true);
        return;
      } catch (e) {
        debugPrint('⚠️ [_playListenSelectAudio] Studio audio failed: $e, falling back to TTS');
      }
    }

    if (_listenSelectSentence.isNotEmpty) {
      debugPrint('🔊 [_playListenSelectAudio] Smart Hybrid TTS speaking: $_listenSelectSentence');
      if (mounted) setState(() => _isPlayingAudio = true);
      await TtsService().speakSentence(_listenSelectSentence);
      if (mounted) setState(() => _isPlayingAudio = false);
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

    final stages = activeNode?.stages;
    _listenAudioUrl = '';
    _sprechenAudioUrl = '';

    if (stages == null || stages.isEmpty) {
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
      debugPrint('🎧 [_initStagesData] Fallback mode (all 8 stages active)');
      _precacheAllVocab();
      return;
    }

    final activeTypes = <String>[];
    for (final rawStage in stages) {
      if (rawStage is! Map) continue;
      final stage = Map<String, dynamic>.from(rawStage);
      final type = stage['type']?.toString();

      if ((type == 'match_pairs' || type == 'word_match') && stage['pairs'] is List) {
        final pairsList = stage['pairs'] as List;
        if (pairsList.isNotEmpty) {
          final newGerman = <String>[];
          final newEnglish = <String>[];
          final newPairs = <String, String>{};
          for (final p in pairsList) {
            if (p is Map) {
              final g = (p['target'] ?? p['german'] ?? p['word'] ?? '').toString().trim();
              final e = (p['native'] ?? p['english'] ?? p['translation'] ?? '').toString().trim();
              if (g.isNotEmpty && e.isNotEmpty) {
                newGerman.add(g);
                newEnglish.add(e);
                newPairs[g] = e;
              }
            }
          }
          if (newGerman.isNotEmpty) {
            _germanWords = newGerman;
            _englishWords = newEnglish..shuffle();
            _solutionPairs = newPairs;
            activeTypes.add('word_match');
          }
        }
      } else if (type == 'listen_tap') {
        final target = stage['targetSentence']?.toString().trim() ?? '';
        if (target.isNotEmpty) {
          _listenTargetSentence = target;
          _listenTarget = target
              .split(RegExp(r'\s+'))
              .where((w) => w.isNotEmpty)
              .toList();
        }
        if (stage['tokens'] is List && (stage['tokens'] as List).isNotEmpty) {
          _listenBank = (stage['tokens'] as List)
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList()
            ..shuffle();
        } else if (_listenTarget.isNotEmpty) {
          _listenBank = List<String>.from(_listenTarget)..shuffle();
        }
        final stageAudio = stage['audioUrl']?.toString().trim();
        _listenAudioUrl = (stageAudio != null && stageAudio.isNotEmpty) ? stageAudio : '';
        activeTypes.add('listen_tap');
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
              .toSet()
              .toList()
            ..shuffle();
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

    debugPrint('🎯 [_initStagesData] Active stage sequence: $_activeStageTypes (total: ${_activeStageTypes.length})');
    _precacheAllVocab();
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
    if (_matchedGerman.contains(word)) return;
    TtsService().speakGerman(word);
    setState(() {
      _selectedGerman = word;
      _evaluateMatch();
    });
  }

  void _onEnglishMatchTap(String word) {
    if (_matchedEnglish.contains(word)) return;
    setState(() {
      _selectedEnglish = word;
      _evaluateMatch();
    });
  }

  void _evaluateMatch() {
    if (_selectedGerman != null && _selectedEnglish != null) {
      if (_solutionPairs[_selectedGerman] == _selectedEnglish) {
        _matchedGerman.add(_selectedGerman!);
        _matchedEnglish.add(_selectedEnglish!);
        _selectedGerman = null;
        _selectedEnglish = null;

        if (_matchedGerman.length == _germanWords.length) {
          _matchFinished = true;
        }
      } else {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) {
            setState(() {
              _selectedGerman = null;
              _selectedEnglish = null;
            });
          }
        });
      }
    }
  }

  // ── Stage: Cloze Test Handlers ────────────────────────────────────
  void _onClozeOptionTap(String option) {
    TtsService().speakGerman(option);
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
    final target = _typeTarget.trim().toLowerCase();

    // Support standard digraph equivalents (ä -> ae, ö -> oe, ü -> ue, ß -> ss)
    final normTyped = typed.replaceAll('ä', 'ae').replaceAll('ö', 'oe').replaceAll('ü', 'ue').replaceAll('ß', 'ss');
    final normTarget = target.replaceAll('ä', 'ae').replaceAll('ö', 'oe').replaceAll('ü', 'ue').replaceAll('ß', 'ss');

    final isCorrect = (typed == target) || (normTyped == normTarget);
    if (isCorrect) {
      TtsService().speakGerman(_typeTarget);
    }
    setState(() {
      _typeCorrect = isCorrect;
    });
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
        debugPrint('🔊 [_playSprechenDemo] Starting studio reference playback: $url');
        await _audioPlayer.stop();
        setState(() {
          _isSprechenDemoPlaying = true;
          _activeSprechenWordIndex = -1;
        });
        await _audioPlayer.play(UrlSource(url));
        return;
      } catch (e) {
        debugPrint('⚠️ [_playSprechenDemo] Studio audio error: $e, falling back to TTS');
      }
    }

    // Smart Hybrid TTS demo with word-by-word karaoke highlighting
    if (_sprechenPrompt.isNotEmpty) {
      if (mounted) {
        setState(() {
          _isSprechenDemoPlaying = true;
          _activeSprechenWordIndex = 0;
        });
      }

      final wordCount = _sprechenKaraokeWords.length;
      int currentWord = 0;
      const wordDuration = Duration(milliseconds: 460);

      _ttsHighlightTimer = Timer.periodic(wordDuration, (timer) {
        if (!mounted || !_isSprechenDemoPlaying) {
          timer.cancel();
          return;
        }
        currentWord++;
        if (currentWord < wordCount) {
          setState(() {
            _activeSprechenWordIndex = currentWord;
          });
        } else {
          timer.cancel();
          if (mounted) {
            setState(() {
              _isSprechenDemoPlaying = false;
              _activeSprechenWordIndex = -1;
            });
          }
        }
      });

      await TtsService().speakSentence(_sprechenPrompt);
    }
  }

  List<String> _cleanWords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r"[.,/#!$%^&*;:{}=\-_`~()?'«»„“”’]"), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  bool _isFuzzyMatch(String w1, String w2) {
    if (w1 == w2) return true;
    final norm1 = w1.replaceAll('ä', 'ae').replaceAll('ö', 'oe').replaceAll('ü', 'ue').replaceAll('ß', 'ss');
    final norm2 = w2.replaceAll('ä', 'ae').replaceAll('ö', 'oe').replaceAll('ü', 'ue').replaceAll('ß', 'ss');
    if (norm1 == norm2) return true;
    if ((norm1.length - norm2.length).abs() <= 1) {
      int diff = 0;
      int minLen = norm1.length < norm2.length ? norm1.length : norm2.length;
      for (int i = 0; i < minLen; i++) {
        if (norm1[i] != norm2[i]) diff++;
      }
      return diff <= 1;
    }
    return false;
  }

  Future<void> _toggleSpeaking() async {
    if (_isSprechenDemoPlaying) {
      _ttsHighlightTimer?.cancel();
      await _audioPlayer.stop();
      await TtsService().stop();
      if (mounted) {
        setState(() {
          _isSprechenDemoPlaying = false;
          _activeSprechenWordIndex = -1;
        });
      }
    }

    if (_isSpeaking) {
      _silenceTimer?.cancel();
      try {
        await _speech.stop();
      } catch (_) {}
      if (mounted) {
        setState(() => _isSpeaking = false);
        _evaluateSpeechPronunciation();
      }
      return;
    }

    setState(() {
      _isSpeaking = true;
      _spokenText = '';
      _speechAccuracy = 0;
      _speechPassed = null;
    });

    try {
      bool available = _speechInitialized;
      if (!available) {
        available = await _speech.initialize(
          onError: (val) => debugPrint('STT error: ${val.errorMsg}'),
          onStatus: (val) {
            debugPrint('STT status: $val');
            if (val == 'done' || val == 'notListening') {
              if (mounted && _isSpeaking) {
                _silenceTimer?.cancel();
                _silenceTimer = Timer(const Duration(milliseconds: 2000), () {
                  if (mounted && _isSpeaking) {
                    setState(() => _isSpeaking = false);
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
        debugPrint('⚠️ Speech recognition unavailable; fallback test simulation');
        _silenceTimer?.cancel();
        _silenceTimer = Timer(const Duration(milliseconds: 1800), () {
          if (mounted && _isSpeaking) {
            setState(() {
              _isSpeaking = false;
              _spokenText = _sprechenPrompt;
            });
            _evaluateSpeechPronunciation();
          }
        });
        return;
      }

      // Query available locales on device to find German (de-DE, de_DE, etc.)
      String germanLocaleId = 'de_DE';
      try {
        final locales = await _speech.locales();
        final match = locales.where((l) => l.localeId.toLowerCase().startsWith('de')).firstOrNull;
        if (match != null) {
          germanLocaleId = match.localeId;
        }
        debugPrint('🇩🇪 [Speech Recognition] Using German locale: $germanLocaleId');
      } catch (e) {
        debugPrint('⚠️ Error querying locales: $e');
      }

      await _speech.listen(
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
                _speech.stop();
                setState(() => _isSpeaking = false);
                _evaluateSpeechPronunciation();
              }
            });
          }
        },
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          cancelOnError: false,
          partialResults: true,
          localeId: germanLocaleId,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      debugPrint('Speech listen exception: $e');
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _spokenText = _sprechenPrompt;
        });
        _evaluateSpeechPronunciation();
      }
    }
  }

  void _evaluateSpeechPronunciation() {
    _silenceTimer?.cancel();
    if (!mounted) return;

    final targetText = _sprechenPrompt.isNotEmpty ? _sprechenPrompt : 'Guten Tag! Wie geht es dir?';
    final targetWords = _cleanWords(targetText);
    final spokenWords = _cleanWords(_spokenText);

    debugPrint('🗣️ [_evaluateSpeechPronunciation] Target: $targetWords | Spoken: $spokenWords');

    int matches = 0;
    for (final tWord in targetWords) {
      if (spokenWords.any((sWord) => _isFuzzyMatch(tWord, sWord))) {
        matches++;
      }
    }

    final accuracy = targetWords.isEmpty ? 100 : ((matches / targetWords.length) * 100).round();
    final threshold = _sprechenMinAccuracy > 0 ? _sprechenMinAccuracy : 75;
    // Parity with Web notes section: >= 75% passes
    final isPassed = accuracy >= threshold;

    setState(() {
      _speechAccuracy = accuracy;
      _speechPassed = isPassed;
    });

    if (isPassed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF15803D),
          content: Text('Ausgezeichnet! ($accuracy% match) 🎉'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFDC2626),
          content: Text('Match $accuracy% — Need $threshold% or higher to pass. Try again!'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _nextStage() {
    _ttsHighlightTimer?.cancel();
    _sprechenAutoPlayTimer?.cancel();
    _silenceTimer?.cancel();
    _audioPlayer.pause();
    TtsService().stop();
    setState(() {
      _isPlayingAudio = false;
      _isSprechenDemoPlaying = false;
      _activeSprechenWordIndex = -1;
      _currentStage++;
    });
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

  void _finishLesson() {
    final xp = widget.node?.xpReward ?? 15;
    final pearls = widget.node?.pearlsReward ?? 20;

    // Complete node on archipelago map and save gamification stats to backend
    ref.read(pathNodesProvider.notifier).completeNode(
      widget.nodeIndex,
      stars: 3,
      scorePct: 100,
      xp: xp,
      pearls: pearls,
    );

    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
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
                      '5',
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
                  'Match the word pairs',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap a German greeting and its matching English meaning.',
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
                          return _buildMatchTile(
                            text: word,
                            isSelected: isSelected,
                            isMatched: isMatched,
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
                          return _buildMatchTile(
                            text: word,
                            isSelected: isSelected,
                            isMatched: isMatched,
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
            title: 'Wunderbar! Perfect Match!',
            subtitle: 'You mastered the core German greetings.',
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
    required VoidCallback onTap,
  }) {
    Color bg = Colors.white;
    Color border = const Color(0xFFE2E8F0);
    Color textColor = const Color(0xFF1E293B);

    if (isMatched) {
      bg = const Color(0xFFF1F5F9);
      border = const Color(0xFFCBD5E1);
      textColor = const Color(0xFF94A3B8);
    } else if (isSelected) {
      bg = const Color(0xFFE0F2FE);
      border = const Color(0xFF0284C7);
      textColor = const Color(0xFF0284C7);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: isMatched ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          height: 60,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: isSelected ? 2.5 : 1.5),
            boxShadow: isMatched
                ? null
                : [
                    BoxShadow(
                      color: isSelected ? const Color(0xFFBAE6FD) : const Color(0xFFE2E8F0),
                      blurRadius: 0,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Text(
            text,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textColor,
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
                  'Listen and tap what you hear',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Center Stage: Dolphin Mascot + Speaker Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedDolphinMascot(
                      size: 110,
                      pose: MascotPose.headphones,
                      isListening: _isPlayingAudio,
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _playListenAudio,
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
                    children: _listenSelected.map((word) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _listenSelected.remove(word);
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
                  children: _listenBank.map((word) {
                    final isUsed = _listenSelected.contains(word);
                    return GestureDetector(
                      onTap: isUsed
                          ? null
                          : () {
                              TtsService().speakGerman(word);
                              setState(() {
                                _listenSelected.add(word);
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
              onPressed: _listenSelected.isEmpty
                  ? null
                  : () {
                      final selectedClean = _listenSelected.join(' ').toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
                      final targetClean = _listenTarget.join(' ').toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
                      final isMatch = selectedClean == targetClean || _listenSelected.join(' ') == _listenTarget.join(' ');
                      setState(() => _listenCorrect = isMatch);
                    },
            ),
          )
        else
          DuoFeedbackSheet(
            isSuccess: _listenCorrect == true,
            title: _listenCorrect == true ? 'Sehr gut! Correct sequence!' : 'Almost there!',
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
                  'Fill in the blank',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap the correct German word to complete the sentence.',
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
            title: _clozeCorrect == true ? 'Hervorragend! Correct word!' : 'Not quite right!',
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
                  'Construct the German sentence',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
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
                    children: _builderSelected.map((word) {
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _builderSelected.remove(word);
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
                  children: _builderBank.map((word) {
                    final isUsed = _builderSelected.contains(word);
                    return GestureDetector(
                      onTap: isUsed
                          ? null
                          : () {
                              TtsService().speakGerman(word);
                              setState(() {
                                _builderSelected.add(word);
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
              onPressed: _builderSelected.isEmpty
                  ? null
                  : () {
                      final selClean = _builderSelected.join(' ').toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
                      final tgtClean = _builderTarget.join(' ').toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
                      final isMatch = selClean == tgtClean || _builderSelected.join(' ') == _builderTarget.join(' ');
                      setState(() => _builderCorrect = isMatch);
                    },
            ),
          )
        else
          DuoFeedbackSheet(
            isSuccess: _builderCorrect == true,
            title: _builderCorrect == true ? 'Hervorragend! Outstanding!' : 'Check punctuation and order',
            subtitle: 'German: "${_builderTargetSentence.isNotEmpty ? _builderTargetSentence : _builderTarget.join(' ')}"',
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
                  'Type the German word',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _typeHint.isNotEmpty ? _typeHint : 'Translate and spell the missing word correctly.',
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
                            hintText: 'Type German word here...',
                            hintStyle: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              color: const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                          ),
                          onChanged: (_) {
                            if (_typeCorrect != null) {
                              setState(() => _typeCorrect = null);
                            }
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

                // German Umlauts Quick-Tap Bar
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
            title: _typeCorrect == true ? 'Ausgezeichnet! Perfect German spelling!' : 'Check the spelling!',
            subtitle: 'Target word: "$_typeTarget"',
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
                  'Conversation with $_dialoguePartnerName',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose the most natural reply to continue the conversation.',
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
            title: _dialogueCorrect == true ? 'Perfekt! Great conversational choice!' : 'Try a different reply!',
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
                  'Listen & Comprehend',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _listenSelectQuestion.isNotEmpty
                      ? _listenSelectQuestion
                      : 'Listen carefully to the audio and select the right option.',
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
            title: _listenSelectCorrect == true ? 'Hervorragend! Correct comprehension!' : 'Almost there!',
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
                  'Pronounce Auf Deutsch',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tap the microphone and speak aloud to Echo the Dolphin.',
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
                                      'Echo is speaking...',
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
                                        'Listen to Echo (Tap to hear)',
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
                              spacing: 6,
                              runSpacing: 8,
                              children: _sprechenKaraokeWords.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final w = entry.value;

                                // 1. Is Echo demonstrating this word right now?
                                final isDemoActive = (_isSprechenDemoPlaying && idx == _activeSprechenWordIndex);

                                // 2. Has the student pronounced this word into the microphone?
                                final spokenWords = _cleanWords(_spokenText);
                                final isPronounced = spokenWords.any((sw) => _isFuzzyMatch(sw, w.clean.toLowerCase()));

                                Color bgColor = Colors.transparent;
                                Color textColor = const Color(0xFF0284C7);
                                Border? border;
                                List<BoxShadow>? shadows;

                                if (isDemoActive) {
                                  // Echo karaoke speaking wave (Dolphin Blue)
                                  bgColor = const Color(0xFF0284C7);
                                  textColor = Colors.white;
                                  border = Border.all(color: const Color(0xFF0369A1), width: 1.5);
                                  shadows = [
                                    BoxShadow(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ];
                                } else if (isPronounced) {
                                  // Student successfully pronounced word (Emerald Green)
                                  bgColor = const Color(0xFF10B981);
                                  textColor = Colors.white;
                                  border = Border.all(color: const Color(0xFF059669), width: 1.5);
                                  shadows = [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ];
                                }

                                return GestureDetector(
                                  onTap: () => TtsService().speakGerman(w.word),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 160),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: (isDemoActive || isPronounced) ? 8 : 4,
                                      vertical: (isDemoActive || isPronounced) ? 4 : 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(8),
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
                                        if (isPronounced) ...[
                                          const SizedBox(width: 3),
                                          const Icon(Icons.check_rounded, color: Colors.white, size: 14),
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

                // Large Microphone Button (No replay button anywhere on this stage)
                Center(
                  child: GestureDetector(
                    onTap: _toggleSpeaking,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isSpeaking ? const Color(0xFFEF4444) : const Color(0xFF0284C7),
                        boxShadow: [
                          BoxShadow(
                            color: _isSpeaking
                                ? const Color(0x66EF4444)
                                : const Color(0xFF0369A1),
                            blurRadius: _isSpeaking ? 16 : 0,
                            offset: _isSpeaking ? const Offset(0, 4) : const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _isSpeaking ? Icons.mic_rounded : Icons.mic_none_rounded,
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
                    _isSpeaking ? 'Listening to your pronunciation...' : 'Tap Mic to Speak',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _isSpeaking ? const Color(0xFFEF4444) : const Color(0xFF64748B),
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
                        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF15803D), size: 24),
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
                        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 24),
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
                                const SizedBox(height: 2),
                                Text(
                                  'Need > 75% match to pass. Tap mic to try again!',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF991B1B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),

        if (_speechPassed == true)
          DuoFeedbackSheet(
            isSuccess: true,
            title: 'Native-Level Pronunciation!',
            subtitle: 'Echo is proud of your German accent! ($_speechAccuracy% match)',
            buttonText: 'SEE RESULTS 🎉',
            onContinue: _nextStage,
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // STAGE 4: Dopamine Celebration & Rewards
  // ══════════════════════════════════════════════════════════════════
  Widget _buildCelebrationStage() {
    final xp = widget.node?.xpReward ?? 15;
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
                  value: '98%',
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
