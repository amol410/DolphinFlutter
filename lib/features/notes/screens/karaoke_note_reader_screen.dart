import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../data/models/karaoke_model.dart';
import '../data/models/note_model.dart';
import '../providers/notes_provider.dart';

class KaraokeNoteReaderScreen extends ConsumerStatefulWidget {
  final NoteModel note;

  const KaraokeNoteReaderScreen({super.key, required this.note});

  @override
  ConsumerState<KaraokeNoteReaderScreen> createState() => _KaraokeNoteReaderScreenState();
}

class _KaraokeNoteReaderScreenState extends ConsumerState<KaraokeNoteReaderScreen> {
  late final AudioPlayer _audioPlayer;
  late final stt.SpeechToText _speech;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _sentenceKeys = {};
  int _lastScrolledSentenceIdx = -1;

  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackRate = 1.0;
  bool _isSprechenMode = false;
  bool _showTranslations = true;
  double _syncOffset = 0.0;

  // Sprechen state
  int? _activeSprechenIndex;
  bool _isListening = false;
  String _spokenText = '';
  int _speechAccuracy = 0;
  bool? _speechPassed;
  final Map<int, int> _sentenceChances = {};
  final Map<int, bool> _sentencePassed = {};
  int _lastPausedIndex = -1;
  Timer? _silenceTimer;

  KaraokeStory get _story => widget.note.karaokeData ?? const KaraokeStory(title: '');
  List<KaraokeSentence> get _sentences => _story.sentences;

  void _scrollToActiveSentence(int idx) {
    if (idx < 0 || idx >= _sentences.length) return;
    if (_lastScrolledSentenceIdx == idx) return;
    _lastScrolledSentenceIdx = idx;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final key = _sentenceKeys[idx];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            alignment: 0.0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOutCubic,
          );
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _speech = stt.SpeechToText();

    _isSprechenMode = _story.isSprechen;
    if (_isSprechenMode) {
      _playbackRate = 0.75;
    }

    _initAudio();
    _initSpeech();
  }

  String _resolveAudioUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.isEmpty) {
      return '${ApiConstants.defaultBaseUrl}/notes/audio/demo_german_story.mp3';
    }
    if (rawUrl.startsWith('http://') || rawUrl.startsWith('https://')) {
      return rawUrl;
    }
    final clean = rawUrl.startsWith('/') ? rawUrl : '/$rawUrl';
    if (clean.startsWith('/api')) {
      return 'https://dolphincoder.com$clean';
    }
    return '${ApiConstants.defaultBaseUrl}$clean';
  }

  Future<void> _initAudio() async {
    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _positionSub = _audioPlayer.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
      });

      _handleTimeUpdate((pos.inMilliseconds / 1000.0) + _syncOffset);
    });

    _durationSub = _audioPlayer.onDurationChanged.listen((dur) {
      if (mounted) {
        setState(() {
          _totalDuration = dur;
        });
      }
    });

    try {
      final url = _resolveAudioUrl(widget.note.audioUrl ?? _story.audioUrl);
      await _audioPlayer.setSourceUrl(url);
      await _audioPlayer.setPlaybackRate(_playbackRate);
    } catch (e) {
      debugPrint('Audio set source error: $e');
    }
  }

  Future<void> _initSpeech() async {
    try {
      await _speech.initialize(
        onError: (val) => debugPrint('Speech error: ${val.errorMsg}'),
        onStatus: (val) {
          debugPrint('Speech status: $val');
          if (val == 'done' || val == 'notListening') {
            if (_isListening && _spokenText.isNotEmpty) {
              _silenceTimer?.cancel();
              _silenceTimer = Timer(const Duration(milliseconds: 1500), () {
                if (mounted && _isListening && _spokenText.isNotEmpty) {
                  _handleAutoSubmit();
                }
              });
            }
          }
        },
      );
    } catch (e) {
      debugPrint('Speech init failed: $e');
    }
  }

  void _handleTimeUpdate(double currentTime) {
    if (_sentences.isEmpty) return;

    for (int i = 0; i < _sentences.length; i++) {
      final s = _sentences[i];
      if (currentTime >= s.start && currentTime <= (s.end + 0.3)) {
        if (_isSprechenMode && _lastPausedIndex != i && !(_sentencePassed[i] ?? false)) {
          if (currentTime >= s.end) {
            _audioPlayer.pause();
            _lastPausedIndex = i;
            if (!mounted) return;
            setState(() {
              _activeSprechenIndex = i;
              _speechPassed = null;
              _spokenText = '';
              _speechAccuracy = 0;
            });
            _startListening(i);
            return;
          }
        }
        if (i != _lastScrolledSentenceIdx && _activeSprechenIndex == null) {
          _scrollToActiveSentence(i);
        }
        break;
      }
    }
  }

  void _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        if (_isListening) {
          _cleanupListening();
        }
        await _audioPlayer.resume();
      }
    } catch (e) {
      debugPrint('Audio toggle play error: $e');
    }
  }

  void _seekTo(double seconds) async {
    _lastScrolledSentenceIdx = -1;
    try {
      await _audioPlayer.seek(Duration(milliseconds: (seconds * 1000).round()));
    } catch (e) {
      debugPrint('Audio seek error: $e');
    }
  }

  void _changeSpeed(double rate) async {
    setState(() {
      _playbackRate = rate;
    });
    await _audioPlayer.setPlaybackRate(rate);
  }

  void _cleanupListening() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
    if (_speech.isListening) {
      _speech.stop();
    }
    if (mounted) {
      setState(() {
        _isListening = false;
      });
    }
  }

  void _startListening(int sIdx) async {
    _cleanupListening();
    _lastScrolledSentenceIdx = -1;
    _scrollToActiveSentence(sIdx);

    final available = await _speech.initialize();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available on this device')),
        );
      }
      return;
    }

    setState(() {
      _isListening = true;
      _spokenText = '';
      _speechAccuracy = 0;
      _speechPassed = null;
    });

    _speech.listen(
      localeId: 'de_DE',
      listenFor: const Duration(seconds: 90),
      pauseFor: const Duration(seconds: 6),
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      ),
      onResult: (result) {
        final text = result.recognizedWords.trim();
        if (mounted) {
          setState(() {
            _spokenText = text;
          });
        }

        if (text.isNotEmpty) {
          _resetSilenceTimer(sIdx);
        }
      },
    );
  }

  void _resetSilenceTimer(int sIdx) {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted && _isListening && _spokenText.isNotEmpty) {
        _handleAutoSubmit();
      }
    });
  }

  void _handleAutoSubmit() {
    if (_spokenText.isEmpty || _activeSprechenIndex == null) return;
    _evaluatePronunciation(_activeSprechenIndex!);
  }

  void _handleManualSubmit(int sIdx) {
    if (_spokenText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please speak in German before submitting!')),
      );
      return;
    }
    _evaluatePronunciation(sIdx);
  }

  void _evaluatePronunciation(int sIdx) {
    _cleanupListening();
    if (sIdx >= _sentences.length) return;

    final targetText = _sentences[sIdx].text;
    final targetWords = _cleanWords(targetText);
    final spokenWords = _cleanWords(_spokenText);

    int matches = 0;
    for (var tWord in targetWords) {
      if (spokenWords.any((sWord) => _isFuzzyMatch(tWord, sWord))) {
        matches++;
      }
    }

    final accuracy = targetWords.isEmpty ? 100 : ((matches / targetWords.length) * 100).round();
    final isMatch = accuracy >= 75;

    final chances = (_sentenceChances[sIdx] ?? 3);

    setState(() {
      _speechAccuracy = accuracy;
      _speechPassed = isMatch;
      if (isMatch) {
        _sentencePassed[sIdx] = true;
      } else {
        _sentenceChances[sIdx] = chances - 1;
      }
    });

    if (isMatch) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('Ausgezeichnet! Great pronunciation! 🎉'),
        ),
      );

      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted && sIdx + 1 < _sentences.length) {
          _playSentence(sIdx + 1);
        }
      });
    } else {
      final left = (_sentenceChances[sIdx] ?? 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.warning,
          content: Text('Not quite ($accuracy%). $left chances remaining!'),
        ),
      );
    }
  }

  List<String> _cleanWords(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[.,/#!$%^&*;:{}=\-_`~()?"«»„“]'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  bool _isFuzzyMatch(String w1, String w2) {
    if (w1 == w2) return true;
    if ((w1.length - w2.length).abs() <= 1) {
      int diff = 0;
      int minLen = w1.length < w2.length ? w1.length : w2.length;
      for (int i = 0; i < minLen; i++) {
        if (w1[i] != w2[i]) diff++;
      }
      return diff <= 1;
    }
    return false;
  }

  void _playSentence(int sIdx) async {
    if (sIdx >= _sentences.length) return;
    _cleanupListening();
    final s = _sentences[sIdx];
    _lastPausedIndex = sIdx - 1;
    _lastScrolledSentenceIdx = -1;
    setState(() {
      _activeSprechenIndex = null;
      _speechPassed = null;
      _spokenText = '';
    });
    _scrollToActiveSentence(sIdx);
    try {
      await _audioPlayer.seek(Duration(milliseconds: (s.start * 1000).round()));
      await _audioPlayer.resume();
    } catch (e) {
      debugPrint('Audio playSentence error: $e');
    }
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _cleanupListening();
    _audioPlayer.stop();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSeconds = (_currentPosition.inMilliseconds / 1000.0) + _syncOffset;
    final totalSeconds = _totalDuration.inMilliseconds / 1000.0;

    // Find active sentence
    int activeSentenceIdx = -1;
    for (int i = 0; i < _sentences.length; i++) {
      if (currentSeconds >= _sentences[i].start && currentSeconds <= _sentences[i].end) {
        activeSentenceIdx = i;
        break;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.onSurface),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.isDark ? AppColors.secondary : AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.school_rounded,
                              color: AppColors.isDark ? AppColors.onSecondaryContainer : Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Karaoke Player',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.onSurface,
                              letterSpacing: -0.4,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceContainerHigh,
                    ),
                    child: Center(
                      child: Icon(Icons.person_rounded, size: 20, color: AppColors.onSurface),
                    ),
                  ),
                ],
              ),
            ),

            // Top Auxiliary Utility Bar (Karaoke Reader + Translate Toggle)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.graphic_eq_rounded, size: 18, color: AppColors.secondary),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'KARAOKE & SPRECHEN READER',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onSurfaceVariant,
                              letterSpacing: 0.8,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showTranslations = !_showTranslations;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _showTranslations ? AppColors.secondaryFixed : AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate_rounded,
                            size: 15,
                            color: _showTranslations ? AppColors.onSecondaryFixed : AppColors.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _showTranslations ? 'EN On' : 'EN Off',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _showTranslations ? AppColors.onSecondaryFixed : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Audio Control Deck
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Mode Selector Segmented Control
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainer,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildModeSegment(
                              icon: Icons.headphones_rounded,
                              label: 'Listening Mode',
                              isActive: !_isSprechenMode,
                              onTap: () {
                                setState(() {
                                  _isSprechenMode = false;
                                  _activeSprechenIndex = null;
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: _buildModeSegment(
                              icon: Icons.record_voice_over_rounded,
                              label: 'Sprechen Mode',
                              isActive: _isSprechenMode,
                              onTap: () {
                                setState(() {
                                  _isSprechenMode = true;
                                });
                                _changeSpeed(0.75);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Playback Timeline & Core Controls
                    Row(
                      children: [
                        // Master Play/Pause circular button reinstated
                        GestureDetector(
                          onTap: _togglePlayPause,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.isDark ? AppColors.secondary : AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.18),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: AppColors.isDark ? AppColors.onSecondaryContainer : Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Track & Timeline
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.note.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_formatTime(_currentPosition)} / ${_formatTime(_totalDuration)}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppColors.secondary,
                                  inactiveTrackColor: AppColors.surfaceContainer,
                                  thumbColor: AppColors.secondary,
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: SliderComponentShape.noOverlay,
                                ),
                                child: Slider(
                                  value: totalSeconds > 0
                                      ? currentSeconds.clamp(0.0, totalSeconds)
                                      : 0.0,
                                  max: totalSeconds > 0 ? totalSeconds : 1.0,
                                  onChanged: (val) => _seekTo(val),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Speed pills centered (Sync removed)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [0.75, 1.0, 1.25].map((s) {
                            final sel = _playbackRate == s;
                            return GestureDetector(
                              onTap: () => _changeSpeed(s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: sel ? (AppColors.isDark ? AppColors.secondary : AppColors.primary) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9999),
                                ),
                                child: Text(
                                  '${s}x',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: sel ? FontWeight.bold : FontWeight.w600,
                                    color: sel
                                        ? (AppColors.isDark ? AppColors.onSecondaryContainer : Colors.white)
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Transcript & Reading Stream
            Expanded(
              child: ListView.separated(
                controller: _scrollController,
                cacheExtent: 5000,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                physics: const BouncingScrollPhysics(),
                itemCount: _sentences.length + 1,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, idx) {
                  // Bottom companion tip card
                  if (idx == _sentences.length) {
                    return _buildCompanionTipCard();
                  }

                  final sentence = _sentences[idx];
                  final isActive = idx == activeSentenceIdx;
                  final isTargetSprechen = idx == _activeSprechenIndex;

                  final key = _sentenceKeys.putIfAbsent(idx, () => GlobalKey());

                  Widget cardWidget;
                  if (isActive || isTargetSprechen) {
                    cardWidget = _buildActiveSentenceCard(sentence, idx, currentSeconds);
                  } else {
                    cardWidget = _buildInactiveSentenceCard(sentence, idx);
                  }

                  return KeyedSubtree(
                    key: key,
                    child: cardWidget,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Segmented mode tab (Listening vs Sprechen)
  Widget _buildModeSegment({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final activeBg = AppColors.isDark ? AppColors.secondary : AppColors.primary;
    final activeFg = AppColors.isDark ? AppColors.onSecondaryContainer : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? activeFg : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                color: isActive ? activeFg : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Bottom companion tip card
  Widget _buildCompanionTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.secondaryFixed,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(Icons.psychology_rounded, color: AppColors.secondary, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text(
                      'Phonetic Kata Tip',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Notice the short soft "e" in words like "lerne". Keep your tongue relaxed against the lower teeth.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Inactive Sentence Card (clean, without 01/02 and without Speaker)
  Widget _buildInactiveSentenceCard(KaraokeSentence sentence, int idx) {
    return GestureDetector(
      onTap: () => _playSentence(idx),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sentence.text,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurface,
                      height: 1.3,
                    ),
                  ),
                  if (_showTranslations && sentence.translation != null && sentence.translation!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      sentence.translation!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontStyle: FontStyle.italic,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(Icons.play_arrow_rounded, size: 18, color: AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Active Sentence Card (clean, without 01/02, speaker, or sync badge)
  Widget _buildActiveSentenceCard(KaraokeSentence sentence, int idx, double currentTime) {
    final words = sentence.words.isNotEmpty
        ? sentence.words
        : sentence.text.split(' ').map((w) => KaraokeWord(word: w, clean: w, start: sentence.start, end: sentence.end)).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.secondaryContainer.withOpacity(0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryContainer.withOpacity(0.12),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // Real-time Karaoke Word Highlighting Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 6,
                  children: words.map((w) {
                    final isWordActive = currentTime >= w.start && currentTime <= w.end;
                    if (isWordActive) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryFixed,
                          borderRadius: BorderRadius.circular(9999),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          w.word,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.onSecondaryFixed,
                          ),
                        ),
                      );
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        w.word,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_showTranslations && sentence.translation != null && sentence.translation!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    sentence.translation!,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // SPRECHEN CHALLENGE BOX (Embedded when in Sprechen mode or active sentence)
          if (_isSprechenMode || _activeSprechenIndex == idx) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sprechen practice header (responsive - eliminates 58px overflow)
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.mic_rounded, color: AppColors.secondary, size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'SPRECHEN PRACTICE',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.secondary,
                                  letterSpacing: 0.6,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          'Chances: ${_sentenceChances[idx] ?? 3}/3',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Text(
                          '≥75%',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Live Speech Recognition Feedback Canvas
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: _isListening ? AppColors.secondaryContainer : AppColors.surfaceContainerHigh,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _isListening ? 'Listening... speak clearly' : 'Tap Speak or Check Now',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _isListening ? AppColors.secondary : AppColors.onSurfaceVariant,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.timer_outlined, size: 13, color: AppColors.onSurfaceVariant),
                                const SizedBox(width: 3),
                                Text(
                                  '3s silence',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Readout box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'YOU SAID:',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurfaceVariant,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _spokenText.isNotEmpty ? '"$_spokenText"' : 'Speak now in German...',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _spokenText.isNotEmpty ? AppColors.onSurface : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_speechAccuracy > 0) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.secondaryFixed,
                              borderRadius: BorderRadius.circular(9999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 16, color: AppColors.secondary),
                                const SizedBox(width: 6),
                                Text(
                                  '$_speechAccuracy% Accuracy ✓ ${(_speechPassed == true) ? 'Ausgezeichnet!' : 'Try Again'}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSecondaryFixed,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Big Action Check Button
                  ElevatedButton.icon(
                    onPressed: () {
                      if (_isListening) {
                        _handleManualSubmit(idx);
                      } else {
                        _startListening(idx);
                      }
                    },
                    icon: Icon(
                      _isListening ? Icons.check_circle_rounded : Icons.mic_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    label: Text(
                      _isListening ? 'Done Speaking (Check Now ✓)' : 'Start Speaking Auf Deutsch',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                      elevation: 2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Bottom action Katas row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _playSentence(idx),
                          icon: Icon(Icons.replay_rounded, size: 16, color: AppColors.onSurface),
                          label: Text(
                            'Listen (${_playbackRate}x)',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceContainerHigh,
                            foregroundColor: AppColors.onSurface,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            if (idx + 1 < _sentences.length) {
                              _playSentence(idx + 1);
                            }
                          },
                          icon: Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: AppColors.isDark ? AppColors.onSecondaryContainer : Colors.white,
                          ),
                          label: Text(
                            'Next Sentence',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.isDark ? AppColors.onSecondaryContainer : Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.isDark ? AppColors.secondary : AppColors.primary,
                            foregroundColor: AppColors.isDark ? AppColors.onSecondaryContainer : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class KaraokeNoteReaderRouteScreen extends ConsumerWidget {
  final String noteId;
  final NoteModel? initialNote;

  const KaraokeNoteReaderRouteScreen({
    super.key,
    required this.noteId,
    this.initialNote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (initialNote != null) {
      return KaraokeNoteReaderScreen(note: initialNote!);
    }
    final noteAsync = ref.watch(noteDetailProvider(noteId));
    return noteAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: AppColors.onSurface),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Text(
            'Failed to load note: $e',
            style: GoogleFonts.plusJakartaSans(color: AppColors.onSurfaceVariant),
          ),
        ),
      ),
      data: (note) => KaraokeNoteReaderScreen(note: note),
    );
  }
}
