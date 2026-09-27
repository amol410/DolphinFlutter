import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/glass_card.dart';
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

  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackRate = 1.0;
  bool _isSprechenMode = false;
  bool _showTranslations = true;

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
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _audioPlayer.onPositionChanged.listen((pos) {
      if (!mounted) return;
      setState(() {
        _currentPosition = pos;
      });

      _handleTimeUpdate(pos.inMilliseconds / 1000.0);
    });

    _audioPlayer.onDurationChanged.listen((dur) {
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
        onError: (val) {
          debugPrint('Speech error: ${val.errorMsg}');
        },
        onStatus: (val) {
          debugPrint('Speech status: $val');
          if (val == 'done' || val == 'notListening') {
            // Note: On Android, the native engine can emit 'notListening' during normal speech pauses.
            // Do NOT immediately evaluate here! Wait for the full 3-second silence timer to count down.
            if (mounted && _isListening) {
              if (_spokenText.isNotEmpty) {
                if (_silenceTimer == null || !_silenceTimer!.isActive) {
                  _resetSilenceTimer(_activeSprechenIndex ?? 0);
                }
              } else {
                setState(() {
                  _isListening = false;
                });
              }
            }
          }
        },
      );
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

  void _handleTimeUpdate(double currentTime) {
    if (!_isSprechenMode || !_isPlaying) return;

    if (_sentences.isEmpty) return;

    int currIdx = _sentences.indexWhere((s) => currentTime >= s.start && currentTime < s.end);

    if (currIdx == -1) {
      for (int i = _sentences.length - 1; i >= 0; i--) {
        if (currentTime >= _sentences[i].start) {
          currIdx = i;
          break;
        }
      }
    }

    if (currIdx >= 0 && currIdx < _sentences.length) {
      final sentence = _sentences[currIdx];
      if (currentTime >= sentence.end) {
        if (_lastPausedIndex != currIdx) {
          _lastPausedIndex = currIdx;
          _audioPlayer.pause();
          setState(() {
            _isPlaying = false;
            _activeSprechenIndex = currIdx;
            _speechAccuracy = 0;
            _speechPassed = null;
            _spokenText = '';
          });
        }
      }
    }
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
  }

  void _seekTo(double seconds) async {
    _cleanupListening();
    final target = Duration(milliseconds: (seconds * 1000).round());
    final targetIdx = _sentences.indexWhere((s) => seconds >= s.start && seconds <= s.end);
    if (targetIdx >= 0) {
      _lastPausedIndex = targetIdx - 1;
      _activeSprechenIndex = null;
    }
    await _audioPlayer.seek(target);
    if (!_isPlaying) {
      await _audioPlayer.resume();
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
          backgroundColor: Colors.green,
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
          backgroundColor: Colors.orange.shade800,
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
    setState(() {
      _activeSprechenIndex = null;
      _speechPassed = null;
      _spokenText = '';
    });
    await _audioPlayer.seek(Duration(milliseconds: (s.start * 1000).round()));
    await _audioPlayer.resume();
  }

  String _formatTime(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _cleanupListening();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSeconds = _currentPosition.inMilliseconds / 1000.0;
    final totalSeconds = _totalDuration.inMilliseconds / 1000.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.note.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showTranslations ? Icons.translate : Icons.g_translate,
              color: _showTranslations ? AppColors.primary : Colors.grey,
            ),
            tooltip: 'Toggle English Translations',
            onPressed: () {
              setState(() {
                _showTranslations = !_showTranslations;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Player Controls Card
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Timeline Slider & Timers
                Row(
                  children: [
                    Text(
                      _formatTime(_currentPosition),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: AppColors.primary,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: totalSeconds > 0
                              ? currentSeconds.clamp(0.0, totalSeconds)
                              : 0.0,
                          max: totalSeconds > 0 ? totalSeconds : 1.0,
                          onChanged: (val) {
                            _seekTo(val);
                          },
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(_totalDuration),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Play / Mode / Speed buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Play / Pause Button
                    InkWell(
                      onTap: _togglePlayPause,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),

                    // Mode Selector (Listening vs Sprechen)
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          _buildModeTab(
                            title: 'Listening',
                            icon: Icons.headphones,
                            isSelected: !_isSprechenMode,
                            onTap: () {
                              setState(() {
                                _isSprechenMode = false;
                                _activeSprechenIndex = null;
                              });
                            },
                          ),
                          _buildModeTab(
                            title: 'Sprechen',
                            icon: Icons.mic,
                            isSelected: _isSprechenMode,
                            onTap: () {
                              setState(() {
                                _isSprechenMode = true;
                              });
                              _changeSpeed(0.75);
                            },
                          ),
                        ],
                      ),
                    ),

                    // Speed Pill
                    DropdownButton<double>(
                      value: _playbackRate,
                      dropdownColor: AppColors.surface,
                      underline: const SizedBox(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      icon: const Icon(Icons.speed, color: AppColors.primary, size: 16),
                      items: const [
                        DropdownMenuItem(value: 0.75, child: Text('0.75x')),
                        DropdownMenuItem(value: 1.0, child: Text('1.0x')),
                        DropdownMenuItem(value: 1.25, child: Text('1.25x')),
                      ],
                      onChanged: (val) {
                        if (val != null) _changeSpeed(val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Sentences List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _sentences.length,
              itemBuilder: (context, idx) {
                final sentence = _sentences[idx];
                final isSentenceActive = currentSeconds >= sentence.start && currentSeconds <= sentence.end;
                final isPassed = _sentencePassed[idx] == true;
                final isSpeakingActive = _activeSprechenIndex == idx;

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSentenceActive
                        ? AppColors.primary.withOpacity(0.12)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSentenceActive
                          ? AppColors.primary.withOpacity(0.5)
                          : isPassed
                              ? Colors.green.withOpacity(0.3)
                              : Colors.white.withOpacity(0.06),
                      width: isSentenceActive ? 1.5 : 1.0,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Sentence Index + Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 10,
                                backgroundColor: isSentenceActive ? AppColors.primary : Colors.white12,
                                child: Text(
                                  '${idx + 1}',
                                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (isSentenceActive) ...[
                                const SizedBox(width: 8),
                                const Text(
                                  'Currently Reading...',
                                  style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                          if (isPassed)
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Ausgezeichnet',
                                  style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Words Flow with Live Word-by-Word Highlighting
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: sentence.words.map((w) {
                          final isWordActive = currentSeconds >= w.start && currentSeconds <= w.end;
                          return GestureDetector(
                            onTap: () => _seekTo(w.start),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: isWordActive
                                    ? AppColors.primary
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: isWordActive
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary.withOpacity(0.5),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                w.word,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isWordActive ? FontWeight.bold : FontWeight.w500,
                                  color: isWordActive ? Colors.white : Colors.white70,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // English Translation
                      if (_showTranslations && sentence.translation.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          sentence.translation,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],

                      // Speaking Practice Box (when paused on this sentence)
                      if (isSpeakingActive) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.purple.shade900.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.purple.shade400.withOpacity(0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.mic, color: Colors.pinkAccent, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'SPRECHEN PRACTICE',
                                        style: TextStyle(
                                          color: Colors.pinkAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Chances: ${(_sentenceChances[idx] ?? 3)}/3',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              // Static English translation for understanding purpose only (no audio, no popup)
                              if (sentence.translation.isNotEmpty) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Meaning: ',
                                        style: TextStyle(
                                          color: Colors.cyan.shade300,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          sentence.translation,
                                          style: TextStyle(
                                            color: Colors.grey.shade300,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Real-time Spoken Transcript or Feedback
                              if (_spokenText.isNotEmpty || _isListening)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _spokenText.isNotEmpty
                                            ? 'You said: "$_spokenText"'
                                            : 'Listening... speak clearly in German',
                                        style: const TextStyle(
                                          color: Colors.pinkAccent,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                      if (_isListening)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 5),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: const BoxDecoration(
                                                  color: Colors.greenAccent,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                _spokenText.isNotEmpty
                                                    ? 'Submits in 3s of silence, or tap Done'
                                                    : 'German speech recognition active',
                                                style: TextStyle(
                                                  color: Colors.greenAccent.shade200,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (_speechAccuracy > 0)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            'Accuracy: $_speechAccuracy%',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 11,
                                              color: (_speechPassed == true) ? Colors.green : Colors.orange,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                              // Action Buttons
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (!isPassed && (_sentenceChances[idx] ?? 3) > 0)
                                    if (!_isListening)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.pink.shade600,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _startListening(idx),
                                        icon: const Icon(Icons.mic, size: 16),
                                        label: const Text('Speak (Auf Deutsch)', style: TextStyle(fontSize: 12)),
                                      )
                                    else ...[
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade600,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _handleManualSubmit(idx),
                                        icon: const Icon(Icons.check_circle_outline, size: 16),
                                        label: const Text('Done Speaking (Check Now ✓)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.grey,
                                          side: const BorderSide(color: Colors.white24),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: _cleanupListening,
                                        child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                                      ),
                                    ],
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white70,
                                      side: const BorderSide(color: Colors.white24),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    onPressed: () => _playSentence(idx),
                                    icon: const Icon(Icons.volume_up, size: 15),
                                    label: const Text('Listen Again', style: TextStyle(fontSize: 12)),
                                  ),
                                  if (idx + 1 < _sentences.length)
                                    TextButton.icon(
                                      onPressed: () => _playSentence(idx + 1),
                                      icon: const Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
                                      label: const Text('Next Sentence', style: TextStyle(color: AppColors.primary, fontSize: 12)),
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
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.white60),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.white60,
              ),
            ),
          ],
        ),
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
      loading: () => const Scaffold(
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
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Text(
            'Failed to load note: $e',
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ),
      data: (note) => KaraokeNoteReaderScreen(note: note),
    );
  }
}
