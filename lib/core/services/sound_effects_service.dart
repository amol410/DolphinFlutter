import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

/// DolphinCoder Ultra-Low-Latency Sound Effects Service
/// Provides instant (<5ms) tactile audio-haptic sensory feedback:
/// - Pop: Quick 750Hz sine pulse (50ms) for item taps and option selection
/// - Correct: Joyful C-Major triad chime (C5 -> E5 -> G5, 300ms) for correct matches
/// - Wrong: Gentle downward saw-tooth bump (220Hz -> 180Hz, 200ms) for mistakes
/// - Fanfare: 4-note victory flourish (C5 -> E5 -> G5 -> C6) for session completion
class SoundEffectsService {
  static final SoundEffectsService _instance = SoundEffectsService._internal();
  factory SoundEffectsService() => _instance;
  SoundEffectsService._internal();

  static SoundEffectsService get instance => _instance;

  // Dedicated low-latency player instances for instant playback (<5ms) without channel contention
  AudioPlayer? _popPlayer;
  AudioPlayer? _correctPlayer;
  AudioPlayer? _wrongPlayer;
  AudioPlayer? _fanfarePlayer;

  bool _initialized = false;
  Future<void>? _initFuture;

  // In-memory pre-rendered PCM fallback buffers (ensures sound plays even in isolated test harnesses)
  Uint8List? _popFallbackWav;
  Uint8List? _correctFallbackWav;
  Uint8List? _wrongFallbackWav;
  Uint8List? _fanfareFallbackWav;

  static const String _popAsset = 'sounds/pop.mp3';
  static const String _correctAsset = 'sounds/correct.mp3';
  static const String _wrongAsset = 'sounds/wrong.mp3';
  static const String _fanfareAsset = 'sounds/fanfare.mp3';

  /// Pre-caches audio player instances in low-latency mode and pre-loads audio buffers.
  Future<void> init() async {
    if (_initialized) return;
    if (_initFuture != null) return _initFuture;

    _initFuture = _doInit();
    return _initFuture;
  }

  Future<void> _doInit() async {
    try {
      _popPlayer = AudioPlayer(playerId: 'dc_sfx_pop');
      _correctPlayer = AudioPlayer(playerId: 'dc_sfx_correct');
      _wrongPlayer = AudioPlayer(playerId: 'dc_sfx_wrong');
      _fanfarePlayer = AudioPlayer(playerId: 'dc_sfx_fanfare');

      final players = [_popPlayer!, _correctPlayer!, _wrongPlayer!, _fanfarePlayer!];

      for (final p in players) {
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setVolume(1.0);
      }

      // Pre-cache memory instances with asset sources
      try {
        await _popPlayer?.setSource(AssetSource(_popAsset));
        await _correctPlayer?.setSource(AssetSource(_correctAsset));
        await _wrongPlayer?.setSource(AssetSource(_wrongAsset));
        await _fanfarePlayer?.setSource(AssetSource(_fanfareAsset));
      } catch (assetErr) {
        debugPrint('⚠️ [SoundEffectsService] Asset preload warning (falling back to memory buffers): $assetErr');
      }

      // Synthesize in-memory fallback buffers matching exact DSP specs
      _popFallbackWav = _generateSineWav(frequency: 750.0, durationMs: 50.0);
      _correctFallbackWav = _generateChimeWav(
        frequencies: [523.25, 659.25, 783.99],
        durationsMs: [75.0, 75.0, 150.0],
      );
      _wrongFallbackWav = _generateSawtoothSweepWav(
        startFreq: 220.0,
        endFreq: 180.0,
        durationMs: 200.0,
      );
      _fanfareFallbackWav = _generateChimeWav(
        frequencies: [523.25, 659.25, 783.99, 1046.50],
        durationsMs: [110.0, 110.0, 110.0, 520.0],
      );

      _initialized = true;
    } catch (e) {
      debugPrint('⚠️ [SoundEffectsService] init error: $e');
    }
  }

  void _ensureInitialized() {
    if (!_initialized && _initFuture == null) {
      init();
    }
  }

  /// Triggers a crisp 750Hz sine pop and light haptic feedback.
  Future<void> playPop() async {
    _ensureInitialized();
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    try {
      if (_popPlayer != null) {
        await _popPlayer!.stop();
        await _popPlayer!.play(AssetSource(_popAsset), mode: PlayerMode.lowLatency);
      } else if (_popFallbackWav != null) {
        final p = AudioPlayer();
        await p.play(BytesSource(_popFallbackWav!));
      }
    } catch (e) {
      if (_popFallbackWav != null && _popPlayer != null) {
        try {
          await _popPlayer!.stop();
          await _popPlayer!.play(BytesSource(_popFallbackWav!));
        } catch (_) {}
      }
    }
  }

  /// Triggers a joyful C-Major triad chime and light haptic feedback.
  Future<void> playCorrect() async {
    _ensureInitialized();
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    try {
      if (_correctPlayer != null) {
        await _correctPlayer!.stop();
        await _correctPlayer!.play(AssetSource(_correctAsset), mode: PlayerMode.lowLatency);
      } else if (_correctFallbackWav != null) {
        final p = AudioPlayer();
        await p.play(BytesSource(_correctFallbackWav!));
      }
    } catch (e) {
      if (_correctFallbackWav != null && _correctPlayer != null) {
        try {
          await _correctPlayer!.stop();
          await _correctPlayer!.play(BytesSource(_correctFallbackWav!));
        } catch (_) {}
      }
    }
  }

  /// Triggers a gentle 220Hz->180Hz downward saw-tooth bump and medium haptic feedback.
  Future<void> playWrong() async {
    _ensureInitialized();
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    try {
      if (_wrongPlayer != null) {
        await _wrongPlayer!.stop();
        await _wrongPlayer!.play(AssetSource(_wrongAsset), mode: PlayerMode.lowLatency);
      } else if (_wrongFallbackWav != null) {
        final p = AudioPlayer();
        await p.play(BytesSource(_wrongFallbackWav!));
      }
    } catch (e) {
      if (_wrongFallbackWav != null && _wrongPlayer != null) {
        try {
          await _wrongPlayer!.stop();
          await _wrongPlayer!.play(BytesSource(_wrongFallbackWav!));
        } catch (_) {}
      }
    }
  }

  /// Triggers a 4-note victory flourish (C5 -> E5 -> G5 -> C6) and celebratory haptics.
  Future<void> playFanfare() async {
    _ensureInitialized();
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}

    try {
      if (_fanfarePlayer != null) {
        await _fanfarePlayer!.stop();
        await _fanfarePlayer!.play(AssetSource(_fanfareAsset), mode: PlayerMode.lowLatency);
      } else if (_fanfareFallbackWav != null) {
        final p = AudioPlayer();
        await p.play(BytesSource(_fanfareFallbackWav!));
      }
    } catch (e) {
      if (_fanfareFallbackWav != null && _fanfarePlayer != null) {
        try {
          await _fanfarePlayer!.stop();
          await _fanfarePlayer!.play(BytesSource(_fanfareFallbackWav!));
        } catch (_) {}
      }
    }
  }

  // --- In-Memory DSP Fallback Synthesis Helpers (RIFF PCM 16-bit Mono 44.1kHz) ---

  static Uint8List _generateSineWav({
    required double frequency,
    required double durationMs,
    int sampleRate = 44100,
  }) {
    final totalSamples = (sampleRate * (durationMs / 1000.0)).round();
    final byteData = ByteData(44 + totalSamples * 2);
    _writeWavHeader(byteData, totalSamples, sampleRate);

    int sampleOffset = 44;
    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final decay = (1.0 - (i / totalSamples));
      final env = decay * decay;
      final sampleVal = (sin(2 * pi * frequency * t) * env * 28000).clamp(-32768, 32767).toInt();
      byteData.setInt16(sampleOffset, sampleVal, Endian.little);
      sampleOffset += 2;
    }

    return byteData.buffer.asUint8List();
  }

  static Uint8List _generateChimeWav({
    required List<double> frequencies,
    required List<double> durationsMs,
    int sampleRate = 44100,
  }) {
    final totalDurationMs = durationsMs.reduce((a, b) => a + b);
    final totalSamples = (sampleRate * (totalDurationMs / 1000.0)).round();
    final byteData = ByteData(44 + totalSamples * 2);
    _writeWavHeader(byteData, totalSamples, sampleRate);

    int sampleOffset = 44;
    for (int seg = 0; seg < frequencies.length; seg++) {
      final freq = frequencies[seg];
      final segSamples = (sampleRate * (durationsMs[seg] / 1000.0)).round();

      for (int i = 0; i < segSamples; i++) {
        if (sampleOffset >= 44 + totalSamples * 2) break;
        final t = i / sampleRate;
        final decay = exp(-4.0 * (i / segSamples));
        final tone = sin(2 * pi * freq * t) + 0.25 * sin(2 * pi * (freq * 2) * t);
        final sampleVal = (tone * decay * 24000).clamp(-32768, 32767).toInt();
        byteData.setInt16(sampleOffset, sampleVal, Endian.little);
        sampleOffset += 2;
      }
    }

    return byteData.buffer.asUint8List();
  }

  static Uint8List _generateSawtoothSweepWav({
    required double startFreq,
    required double endFreq,
    required double durationMs,
    int sampleRate = 44100,
  }) {
    final totalSamples = (sampleRate * (durationMs / 1000.0)).round();
    final byteData = ByteData(44 + totalSamples * 2);
    _writeWavHeader(byteData, totalSamples, sampleRate);

    double phase = 0.0;
    int sampleOffset = 44;
    for (int i = 0; i < totalSamples; i++) {
      final progress = i / totalSamples;
      final f = startFreq + (endFreq - startFreq) * progress;
      phase += 2 * pi * f / sampleRate;
      final decay = pow(1.0 - progress, 1.8);
      final val = (sin(phase) + 0.35 * sin(2 * phase) + 0.15 * sin(3 * phase)) * decay;
      final sampleVal = (val * 24000).clamp(-32768, 32767).toInt();
      byteData.setInt16(sampleOffset, sampleVal, Endian.little);
      sampleOffset += 2;
    }

    return byteData.buffer.asUint8List();
  }

  static void _writeWavHeader(ByteData b, int totalSamples, int sampleRate) {
    b.setUint8(0, 0x52); b.setUint8(1, 0x49); b.setUint8(2, 0x46); b.setUint8(3, 0x46); // RIFF
    b.setUint32(4, 36 + totalSamples * 2, Endian.little);
    b.setUint8(8, 0x57); b.setUint8(9, 0x41); b.setUint8(10, 0x56); b.setUint8(11, 0x45); // WAVE
    b.setUint8(12, 0x66); b.setUint8(13, 0x6D); b.setUint8(14, 0x74); b.setUint8(15, 0x20); // fmt
    b.setUint32(16, 16, Endian.little); // Subchunk1Size
    b.setUint16(20, 1, Endian.little);  // PCM
    b.setUint16(22, 1, Endian.little);  // Mono
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    b.setUint16(32, 2, Endian.little);  // BlockAlign
    b.setUint16(34, 16, Endian.little); // BitsPerSample
    b.setUint8(36, 0x64); b.setUint8(37, 0x61); b.setUint8(38, 0x74); b.setUint8(39, 0x61); // data
    b.setUint32(40, totalSamples * 2, Endian.little);
  }

  /// Releases resources held by the low-latency audio players.
  void dispose() {
    _popPlayer?.dispose();
    _correctPlayer?.dispose();
    _wrongPlayer?.dispose();
    _fanfarePlayer?.dispose();
    _popPlayer = null;
    _correctPlayer = null;
    _wrongPlayer = null;
    _fanfarePlayer = null;
    _initialized = false;
    _initFuture = null;
  }
}
