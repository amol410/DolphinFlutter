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
  String _listenAudioUrl = '/api/notes/audio/db/5';

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

  late final stt.SpeechToText _speech;
  bool _speechInitialized = false;
  bool _isSpeaking = false;
  bool? _speechPassed;
  String _spokenText = '';
  int _speechAccuracy = 0;
  Timer? _silenceTimer;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _audioPlayer = AudioPlayer();

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
      } else if (firstType == 'sprechen') {
        _triggerSprechenAutoPlay();
      }
    }
  }

  @override
  void dispose() {
    _sprechenAutoPlayTimer?.cancel();
    _silenceTimer?.cancel();
    _playerCompleteSub?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    try {
      _speech.stop();
    } catch (_) {}
    _audioPlayer.stop();
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
    final rawUrl = _listenAudioUrl.isNotEmpty ? _listenAudioUrl : (widget.node?.audioUrl ?? '');
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
    final rawUrl = _listenAudioUrl.isNotEmpty ? _listenAudioUrl : (widget.node?.audioUrl ?? '');
    final url = _resolveAudioUrl(rawUrl);

    if (url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No audio attached to this stage.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    try {
      if (!mounted) return;
      debugPrint('🔊 [_playListenAudio] Replaying sentence audio: $url');
      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(url));
      _preparedAudioUrl = url;
      if (mounted) setState(() => _isPlayingAudio = true);
    } catch (e) {
      if (mounted) {
        setState(() => _isPlayingAudio = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio error: $e'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
    final nodeAudio = activeNode?.audioUrl;
    if (stages == null || stages.isEmpty) {
      if (nodeAudio != null && nodeAudio.isNotEmpty) {
        _listenAudioUrl = nodeAudio;
      }
      _activeStageTypes = ['word_match', 'listen_tap', 'sentence_builder', 'sprechen'];
      debugPrint('🎧 [_initStagesData] Fallback mode (all 4 stages): audio: $_listenAudioUrl');
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
        if (stageAudio != null && stageAudio.isNotEmpty) {
          _listenAudioUrl = stageAudio;
        } else if (nodeAudio != null && nodeAudio.isNotEmpty) {
          _listenAudioUrl = nodeAudio;
        }
        activeTypes.add('listen_tap');
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
        if (audio != null && audio.isNotEmpty) {
          _sprechenAudioUrl = audio;
        }
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
                clean: e.value,
                start: e.key * 0.5,
                end: (e.key * 0.5) + 0.45,
              ))
          .toList();
    }

    if (_sprechenAudioUrl.isEmpty && nodeAudio != null && nodeAudio.isNotEmpty) {
      _sprechenAudioUrl = nodeAudio;
    }

    if (_listenAudioUrl.isEmpty) {
      if (nodeAudio != null && nodeAudio.isNotEmpty) {
        _listenAudioUrl = nodeAudio;
      } else {
        _listenAudioUrl = '/api/notes/audio/db/5';
      }
    }

    if (activeTypes.isNotEmpty) {
      _activeStageTypes = activeTypes;
    } else {
      _activeStageTypes = ['word_match', 'listen_tap', 'sentence_builder', 'sprechen'];
    }

    debugPrint('🎯 [_initStagesData] Active stage sequence: $_activeStageTypes (total: ${_activeStageTypes.length})');
  }

  void _onGermanMatchTap(String word) {
    if (_matchedGerman.contains(word)) return;
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
    final rawUrl = _sprechenAudioUrl.isNotEmpty ? _sprechenAudioUrl : '';
    if (rawUrl.isEmpty) {
      debugPrint('ℹ️ [_playSprechenDemo] No audio URL configured for stage 3 sprechen');
      return;
    }
    final url = _resolveAudioUrl(rawUrl);
    if (url.isEmpty) return;

    try {
      if (!mounted) return;
      debugPrint('🔊 [_playSprechenDemo] Starting one-time reference playback: $url');
      await _audioPlayer.stop();
      setState(() {
        _isSprechenDemoPlaying = true;
        _activeSprechenWordIndex = -1;
      });
      await _audioPlayer.play(UrlSource(url));
    } catch (e) {
      debugPrint('⚠️ [_playSprechenDemo] Audio playback error: $e');
      if (mounted) {
        setState(() {
          _isSprechenDemoPlaying = false;
          _activeSprechenWordIndex = -1;
        });
      }
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
      await _audioPlayer.stop();
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
    _sprechenAutoPlayTimer?.cancel();
    _silenceTimer?.cancel();
    _audioPlayer.pause();
    setState(() {
      _isPlayingAudio = false;
      _isSprechenDemoPlaying = false;
      _activeSprechenWordIndex = -1;
      _currentStage++;
    });
    if (_currentStage < _activeStageTypes.length) {
      final nextType = _activeStageTypes[_currentStage];
      if (nextType == 'listen_tap') {
        _prepareListenAudio();
      } else if (nextType == 'sprechen') {
        _triggerSprechenAutoPlay();
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
      case 'sentence_builder':
        return _buildSentenceBuilderStage();
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
                    AnimatedDolphinMascot(
                      size: 95,
                      pose: _speechPassed == true
                          ? MascotPose.celebrate
                          : (_isSpeaking
                              ? MascotPose.thinking
                              : (_isSprechenDemoPlaying ? MascotPose.jump : null)),
                      isListening: _isSpeaking,
                      isCelebrating: _speechPassed == true,
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
                              ),
                            Wrap(
                              spacing: 4,
                              runSpacing: 6,
                              children: _sprechenKaraokeWords.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final w = entry.value;
                                final isWordActive = (_isSprechenDemoPlaying && idx == _activeSprechenWordIndex);

                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isWordActive ? 8 : 3,
                                    vertical: isWordActive ? 3 : 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isWordActive
                                        ? const Color(0xFF0284C7)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: isWordActive
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    w.word,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: isWordActive
                                          ? Colors.white
                                          : const Color(0xFF0284C7),
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
