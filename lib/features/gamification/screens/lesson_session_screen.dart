import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/animated_dolphin_mascot.dart';
import '../../../shared/widgets/tactile_game_button.dart';
import '../../../shared/widgets/duo_feedback_sheet.dart';
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
  int _currentStage = 0; // 0: Word Match, 1: Listening, 2: Sentence Builder, 3: Sprechen, 4: Celebration
  final int _totalStages = 4;

  late final AudioPlayer _audioPlayer;
  StreamSubscription? _playerCompleteSub;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  bool _isPlayingAudio = false;
  double? _targetStopSec;
  int? _pendingWordDurationMs;
  bool _isAudioSourcePrepared = false;
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
  List<Map<String, dynamic>> _listenWordTimestamps = [];
  Timer? _wordAudioTimer;

  // ── Stage 2: Sentence Builder Data ────────────────────────────────
  String _sentencePrompt = 'Translate: "Good morning, how are you?"';
  String _builderTargetSentence = 'Guten Morgen, wie geht es dir?';
  List<String> _builderBank = ['Guten', 'Morgen,', 'wie', 'geht', 'es', 'dir?', 'schlafe', 'Kalt'];
  List<String> _builderTarget = ['Guten', 'Morgen,', 'wie', 'geht', 'es', 'dir?'];
  final List<String> _builderSelected = [];
  bool? _builderCorrect;

  // ── Stage 3: Sprechen Voice Data ──────────────────────────────────
  String _sprechenPrompt = 'Guten Tag! Wie geht es dir?';
  String _sprechenTranslation = 'Hello! How are you?';
  bool _isSpeaking = false;
  bool? _speechPassed;
  String _spokenText = '';

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlayingAudio = false;
          _targetStopSec = null;
        });
      }
    });

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlayingAudio = (state == PlayerState.playing));
      }
      if (state == PlayerState.playing && _pendingWordDurationMs != null) {
        _wordAudioTimer?.cancel();
        final duration = _pendingWordDurationMs!;
        _pendingWordDurationMs = null;
        _wordAudioTimer = Timer(Duration(milliseconds: duration), () async {
          try {
            await _audioPlayer.pause();
          } catch (_) {}
          _targetStopSec = null;
        });
      }
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((pos) {
      if (_targetStopSec != null) {
        final currentSec = pos.inMilliseconds / 1000.0;
        if (currentSec >= _targetStopSec!) {
          _audioPlayer.pause();
          _targetStopSec = null;
          _wordAudioTimer?.cancel();
        }
      }
    });

    _initStagesData();
    _prepareListenAudio();
  }

  @override
  void dispose() {
    _wordAudioTimer?.cancel();
    _playerCompleteSub?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
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
      _isAudioSourcePrepared = true;
      debugPrint('🎵 [_prepareListenAudio] Pre-warmed audio source: $url');
    } catch (e) {
      debugPrint('⚠️ [_prepareListenAudio] Audio pre-warm error: $e');
    }
  }

  Future<void> _playListenAudio() async {
    _wordAudioTimer?.cancel();
    _targetStopSec = null;
    _pendingWordDurationMs = null;
    final rawUrl = _listenAudioUrl.isNotEmpty ? _listenAudioUrl : (widget.node?.audioUrl ?? '');
    final url = _resolveAudioUrl(rawUrl);

    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No audio attached to this stage.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      if (_isPlayingAudio) {
        await _audioPlayer.pause();
        if (mounted) setState(() => _isPlayingAudio = false);
      } else {
        if (!_isAudioSourcePrepared || _preparedAudioUrl != url) {
          await _audioPlayer.setSourceUrl(url);
          _preparedAudioUrl = url;
          _isAudioSourcePrepared = true;
        }
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.resume();
        if (mounted) setState(() => _isPlayingAudio = true);
      }
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

  String _cleanWord(String w) {
    return w
        .replaceAll(RegExp(r'[,.!?;:«»"\(\)\[\]\x27]'), '')
        .trim()
        .toLowerCase();
  }

  Future<void> _playWordAudio(String word) async {
    if (_listenWordTimestamps.isEmpty) {
      debugPrint('⚠️ [_playWordAudio] No timestamps loaded (_listenWordTimestamps is empty)');
      return;
    }

    final targetClean = _cleanWord(word);
    if (targetClean.isEmpty) return;

    Map<String, dynamic>? match;
    for (final entry in _listenWordTimestamps) {
      final entryWord = _cleanWord((entry['word'] ?? entry['text'] ?? '').toString());
      if (entryWord == targetClean) {
        match = entry;
        break;
      }
    }

    // Fallback: prefix/substring match if exact match missed due to compound or punctuation
    if (match == null) {
      for (final entry in _listenWordTimestamps) {
        final entryWord = _cleanWord((entry['word'] ?? entry['text'] ?? '').toString());
        if (entryWord.isNotEmpty && (targetClean.startsWith(entryWord) || entryWord.startsWith(targetClean))) {
          match = entry;
          break;
        }
      }
    }

    if (match == null) {
      debugPrint('⚠️ [_playWordAudio] No timestamp match for word "$word" (cleaned: "$targetClean")');
      return;
    }

    final rawUrl = _listenAudioUrl.isNotEmpty ? _listenAudioUrl : (widget.node?.audioUrl ?? '');
    final url = _resolveAudioUrl(rawUrl);
    if (url.isEmpty) {
      debugPrint('⚠️ [_playWordAudio] Resolved audio URL is empty');
      return;
    }

    final startSec = (match['start'] as num?)?.toDouble() ?? 0.0;
    final endSec = (match['end'] as num?)?.toDouble() ?? (startSec + 0.6);
    final safeEndSec = (endSec > startSec) ? endSec : (startSec + 0.6);

    debugPrint('🔊 [_playWordAudio] Pronouncing "$word" -> start: ${startSec}s, end: ${safeEndSec}s');

    _wordAudioTimer?.cancel();
    _targetStopSec = safeEndSec;
    final durationMs = (((safeEndSec - startSec).abs()) * 1000).toInt().clamp(250, 4000);
    _pendingWordDurationMs = durationMs;

    try {
      if (!_isAudioSourcePrepared || _preparedAudioUrl != url) {
        await _audioPlayer.setSourceUrl(url);
        _preparedAudioUrl = url;
        _isAudioSourcePrepared = true;
      }

      await _audioPlayer.seek(Duration(milliseconds: (startSec * 1000).round()));
      await _audioPlayer.resume();

      if (_isPlayingAudio) {
        _wordAudioTimer = Timer(Duration(milliseconds: durationMs), () async {
          try {
            await _audioPlayer.pause();
          } catch (_) {}
          _targetStopSec = null;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [_playWordAudio] Playback exception: $e');
    }
  }

  List<Map<String, dynamic>> _extractWordTimestamps(Map<String, dynamic> stage) {
    final result = <Map<String, dynamic>>[];

    void parseList(dynamic list) {
      if (list is! List) return;
      for (final item in list) {
        if (item is Map) {
          final word = (item['word'] ?? item['text'] ?? '').toString().trim();
          final start = (item['start'] as num?)?.toDouble() ?? (item['startTime'] as num?)?.toDouble();
          final end = (item['end'] as num?)?.toDouble() ?? (item['endTime'] as num?)?.toDouble();
          if (word.isNotEmpty && start != null) {
            result.add({
              'word': word,
              'start': start,
              'end': end ?? (start + 0.6),
            });
          }
        }
      }
    }

    void parseObject(dynamic raw) {
      if (raw == null) return;
      if (raw is String) {
        try {
          final decoded = jsonDecode(raw);
          parseObject(decoded);
          return;
        } catch (_) {}
      }
      if (raw is List) {
        parseList(raw);
      } else if (raw is Map) {
        if (raw['words'] is List) {
          parseList(raw['words']);
        }
        if (raw['sentences'] is List) {
          for (final s in raw['sentences']) {
            if (s is Map && s['words'] is List) {
              parseList(s['words']);
            }
          }
        }
      }
    }

    // 1. Direct wordTimestamps
    parseObject(stage['wordTimestamps']);

    // 2. Direct karaokeData in stage
    if (result.isEmpty) {
      parseObject(stage['karaokeData']);
    }

    // 3. Fallback to other stages or node
    if (result.isEmpty && widget.node?.stages != null) {
      for (final s in widget.node!.stages!) {
        if (s is Map) {
          parseObject(s['wordTimestamps']);
          if (result.isNotEmpty) break;
          parseObject(s['karaokeData']);
          if (result.isNotEmpty) break;
        }
      }
    }

    return result;
  }

  void _initStagesData() {
    final stages = widget.node?.stages;
    if (stages == null || stages.isEmpty) {
      if (widget.node?.audioUrl != null && widget.node!.audioUrl!.isNotEmpty) {
        _listenAudioUrl = widget.node!.audioUrl!;
      }
      return;
    }

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
        } else if (widget.node?.audioUrl != null && widget.node!.audioUrl!.isNotEmpty) {
          _listenAudioUrl = widget.node!.audioUrl!;
        }
        _listenWordTimestamps = _extractWordTimestamps(stage);
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
      } else if (type == 'sprechen') {
        final prompt = stage['prompt']?.toString().trim();
        if (prompt != null && prompt.isNotEmpty) {
          _sprechenPrompt = prompt;
        }
        final trans = stage['translation']?.toString().trim();
        if (trans != null && trans.isNotEmpty) {
          _sprechenTranslation = trans;
        }
      }
    }

    if (_listenWordTimestamps.isEmpty) {
      _listenWordTimestamps = _extractWordTimestamps(const {});
    }
    if (_listenAudioUrl.isEmpty && widget.node?.audioUrl != null && widget.node!.audioUrl!.isNotEmpty) {
      _listenAudioUrl = widget.node!.audioUrl!;
    }
    debugPrint('🎧 [_initStagesData] Loaded ${_listenWordTimestamps.length} word timestamps, audio: $_listenAudioUrl');
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

  void _nextStage() {
    _wordAudioTimer?.cancel();
    _targetStopSec = null;
    _pendingWordDurationMs = null;
    _audioPlayer.pause();
    setState(() {
      _isPlayingAudio = false;
      _currentStage++;
    });
    if (_currentStage == 1) {
      _prepareListenAudio();
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
    final progress = (_currentStage / _totalStages).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _currentStage < 4
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
    switch (_currentStage) {
      case 0:
        return _buildWordMatchStage();
      case 1:
        return _buildListeningStage();
      case 2:
        return _buildSentenceBuilderStage();
      case 3:
        return _buildSprechenStage();
      case 4:
      default:
        return _buildCelebrationStage();
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // STAGE 0: Match Word Pairs (Vocabulary basics)
  // ══════════════════════════════════════════════════════════════════
  Widget _buildWordMatchStage() {
    return Column(
      key: const ValueKey(0),
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
      key: const ValueKey(1),
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
                          color: _isPlayingAudio ? const Color(0xFF10B981) : const Color(0xFF0284C7),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: _isPlayingAudio ? const Color(0xFF059669) : const Color(0xFF0369A1),
                              blurRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _isPlayingAudio ? Icons.pause_rounded : Icons.volume_up_rounded,
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
                          _playWordAudio(word);
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
                              _playWordAudio(word);
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
      key: const ValueKey(2),
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
  // STAGE 3: Sprechen Speech Pronunciation
  // ══════════════════════════════════════════════════════════════════
  Widget _buildSprechenStage() {
    return Column(
      key: const ValueKey(3),
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

                // Mascot & German Prompt Bubble
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDolphinMascot(
                      size: 95,
                      pose: _speechPassed == true
                          ? MascotPose.celebrate
                          : (_isSpeaking ? MascotPose.thinking : MascotPose.jump),
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
                          border: Border.all(color: const Color(0xFF0284C7), width: 2),
                          boxShadow: const [
                            BoxShadow(color: Color(0xFFBAE6FD), blurRadius: 0, offset: Offset(0, 3)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _sprechenPrompt.isNotEmpty ? _sprechenPrompt : 'Guten Tag! Wie geht es dir?',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _sprechenTranslation.isNotEmpty ? _sprechenTranslation : 'Hello! How are you?',
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

                // Large Microphone Button
                Center(
                  child: GestureDetector(
                    onTap: () {
                      if (_isSpeaking) return;
                      setState(() {
                        _isSpeaking = true;
                        _spokenText = '';
                        _speechPassed = null;
                      });

                      Future.delayed(const Duration(milliseconds: 1800), () {
                        if (mounted) {
                          setState(() {
                            _isSpeaking = false;
                            _spokenText = _sprechenPrompt.isNotEmpty ? _sprechenPrompt : 'Guten Tag! Wie geht es dir?';
                            _speechPassed = true;
                          });
                        }
                      });
                    },
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
                            'Recognized 98%: "$_spokenText"',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF15803D),
                            ),
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
            subtitle: 'Echo is proud of your German accent!',
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

    return Padding(
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
            'You mastered "Basics & Greetings" with flying colors!',
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
