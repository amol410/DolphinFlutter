import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'speech_lifecycle_bridge.dart';
import 'tts_service.dart';

/// Current lifecycle state of the speech recognition pipeline.
enum SpeechServiceState {
  idle,
  initializing,
  ready,
  listening,
  processing,
  error,
}

/// Categorized speech recognition error types for UI and recovery.
enum SpeechRecognitionErrorType {
  permissionDenied,
  permanentlyDenied,
  noSpeechDetected,
  noMatch,
  busy,
  network,
  notAvailable,
  unknown,
}

/// Data payload emitted upon partial or final speech recognition.
class SpeechTranscriptionPayload {
  final String text;
  final List<String> words;
  final double confidence;
  final bool isFinal;

  const SpeechTranscriptionPayload({
    required this.text,
    required this.words,
    required this.confidence,
    required this.isFinal,
  });

  @override
  String toString() =>
      'SpeechTranscriptionPayload(text: "$text", words: ${words.length}, confidence: $confidence, isFinal: $isFinal)';
}

/// Production-Grade Speech Recognition Service for DolphinCoder
/// Reconstructed with Duolingo-Parity Acoustic Safeguards:
/// - Preflight permission checking with settings deep-linking
/// - Audio focus & 200ms hardware settling guard (halts TTS before mic opens)
/// - BCP-47 locale negotiation with regional fallback
/// - Real-time RMS audio level normalization (0.0 to 1.0)
/// - Instant `finalResult` recognition without premature timeout race conditions
class SpeechRecognitionService {
  static final SpeechRecognitionService _instance =
      SpeechRecognitionService._internal();
  factory SpeechRecognitionService() => _instance;
  SpeechRecognitionService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isInitialized = false;
  SpeechServiceState _state = SpeechServiceState.idle;
  SpeechServiceState get state => _state;

  final _stateController = StreamController<SpeechServiceState>.broadcast();
  Stream<SpeechServiceState> get stateStream => _stateController.stream;

  final _soundLevelController = StreamController<double>.broadcast();
  Stream<double> get soundLevelStream => _soundLevelController.stream;

  final _transcriptionController =
      StreamController<SpeechTranscriptionPayload>.broadcast();
  Stream<SpeechTranscriptionPayload> get transcriptionStream =>
      _transcriptionController.stream;

  final _errorController =
      StreamController<SpeechRecognitionErrorType>.broadcast();
  Stream<SpeechRecognitionErrorType> get errorStream => _errorController.stream;

  Timer? _silenceTimer;
  Timer? _maxListenTimer;
  String _lastRecognizedText = '';
  List<stt.LocaleName> _cachedLocales = [];
  DateTime? _listenStartTime;

  /// Duolingo Parity: recognizerPreRoll calibration window (250ms)
  /// Discards speaker ring, button clicks, and acoustic reverberation before speech scoring.
  static const Duration recognizerPreRoll = Duration(milliseconds: 250);

  void _setState(SpeechServiceState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Check and request microphone and speech permissions.
  Future<PermissionStatus> checkAndRequestPermissions() async {
    final micStatus = await Permission.microphone.status;
    if (micStatus.isPermanentlyDenied) {
      return PermissionStatus.permanentlyDenied;
    }
    if (!micStatus.isGranted) {
      final requestStatus = await Permission.microphone.request();
      if (!requestStatus.isGranted) {
        return requestStatus;
      }
    }

    return PermissionStatus.granted;
  }

  /// Initialize speech engine with error and status interceptors.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    _setState(SpeechServiceState.initializing);
    try {
      final perm = await checkAndRequestPermissions();
      if (!perm.isGranted) {
        _setState(SpeechServiceState.error);
        _errorController.add(
          perm.isPermanentlyDenied
              ? SpeechRecognitionErrorType.permanentlyDenied
              : SpeechRecognitionErrorType.permissionDenied,
        );
        return false;
      }

      final available = await _speech.initialize(
        onError: _handleNativeError,
        onStatus: _handleNativeStatus,
        debugLogging: kDebugMode,
      );

      _isInitialized = available;
      if (available) {
        _setState(SpeechServiceState.ready);
        try {
          _cachedLocales = await _speech.locales();
        } catch (_) {}
      } else {
        _setState(SpeechServiceState.error);
        _errorController.add(SpeechRecognitionErrorType.notAvailable);
      }
      return available;
    } catch (e) {
      debugPrint('SpeechRecognitionService init exception: $e');
      _setState(SpeechServiceState.error);
      _errorController.add(SpeechRecognitionErrorType.unknown);
      return false;
    }
  }

  /// Negotiate optimal locale ID matching target language ('en' or 'de').
  String resolveLocale(String targetLanguageCode) {
    final isEnglish = targetLanguageCode.toLowerCase() == 'en';
    if (_cachedLocales.isEmpty) {
      return isEnglish ? 'en_US' : 'de_DE';
    }

    if (isEnglish) {
      // Prioritize regional English based on available device models
      final preferred = ['en_us', 'en_gb', 'en_in', 'en_au', 'en_ca'];
      for (final pref in preferred) {
        final match = _cachedLocales.where((l) {
          final id = l.localeId.toLowerCase().replaceAll('-', '_');
          return id.contains(pref);
        }).firstOrNull;
        if (match != null) return match.localeId;
      }
      final anyEn = _cachedLocales
          .where((l) => l.localeId.toLowerCase().startsWith('en'))
          .firstOrNull;
      if (anyEn != null) return anyEn.localeId;
      return 'en_US';
    } else {
      // German
      final preferred = ['de_de', 'de_at', 'de_ch'];
      for (final pref in preferred) {
        final match = _cachedLocales.where((l) {
          final id = l.localeId.toLowerCase().replaceAll('-', '_');
          return id.contains(pref);
        }).firstOrNull;
        if (match != null) return match.localeId;
      }
      final anyDe = _cachedLocales
          .where((l) => l.localeId.toLowerCase().startsWith('de'))
          .firstOrNull;
      if (anyDe != null) return anyDe.localeId;
      return 'de_DE';
    }
  }

  /// Start listening with hardware settling guard and anti-collision checks.
  Future<bool> startListening({
    required String targetLanguageCode,
    Duration pauseFor = const Duration(seconds: 3),
    Duration listenFor = const Duration(seconds: 30),
    Function(SpeechTranscriptionPayload)? onResultCallback,
  }) async {
    _silenceTimer?.cancel();
    _maxListenTimer?.cancel();

    // 1. Acoustic Feedback Prevention: Halt TTS and audio players completely
    await TtsService().stop();

    // 2. Duolingo Parity: Check Bluetooth Headset & activate SCO voice routing if connected
    final hasBluetoothHeadset = await SpeechLifecycleBridge.isBluetoothHeadsetConnected();
    if (hasBluetoothHeadset) {
      await SpeechLifecycleBridge.startBluetoothSco();
    }
    await SpeechLifecycleBridge.requestAudioFocus();

    // 3. Duolingo Pre-Roll Settling: 250ms hardware settling guard to allow audio line to switch from DAC to ADC
    await Future.delayed(recognizerPreRoll);
    _listenStartTime = DateTime.now();

    if (!_isInitialized) {
      final ok = await initialize();
      if (!ok) return false;
    }

    if (_speech.isListening) {
      await _speech.stop();
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final localeId = resolveLocale(targetLanguageCode);
    debugPrint('🎙️ [SpeechRecognitionService] Listening with locale: $localeId');

    _lastRecognizedText = '';
    _setState(SpeechServiceState.listening);

    try {
      await _speech.listen(
        listenOptions: stt.SpeechListenOptions(
          listenMode: stt.ListenMode.dictation,
          partialResults: true,
          cancelOnError: false,
          autoPunctuation: false,
          localeId: localeId,
          listenFor: listenFor,
          pauseFor: pauseFor,
        ),
        onResult: (result) {
          _handleSpeechResult(result, onResultCallback);
        },
        onSoundLevelChange: (level) {
          // Normalizes RMS dB (-2 to 10 dB) into 0.0 - 1.0 clamped value
          final normalized = ((level + 2.0) / 12.0).clamp(0.0, 1.0);
          _soundLevelController.add(normalized);
        },
      );

      // Maximum timeout safety watchdog
      _maxListenTimer = Timer(listenFor + const Duration(seconds: 2), () {
        if (_state == SpeechServiceState.listening) {
          stopListening();
        }
      });

      return true;
    } catch (e) {
      debugPrint('Speech listen exception: $e');
      _setState(SpeechServiceState.error);
      _errorController.add(SpeechRecognitionErrorType.unknown);
      return false;
    }
  }

  void _handleSpeechResult(
    SpeechRecognitionResult result,
    Function(SpeechTranscriptionPayload)? onResultCallback,
  ) {
    // Duolingo Pre-Roll: Discard early speech recognition packets during the first 250ms
    // to prevent chassis vibration, button tap clicks, or residual speaker ring from corrupting recognition
    if (_listenStartTime != null &&
        DateTime.now().difference(_listenStartTime!) < recognizerPreRoll) {
      debugPrint(
          '🛡️ [SpeechRecognitionService] Discarding pre-roll audio sample (${DateTime.now().difference(_listenStartTime!).inMilliseconds}ms < ${recognizerPreRoll.inMilliseconds}ms)');
      return;
    }

    final text = result.recognizedWords.trim();
    if (text.isNotEmpty) {
      _lastRecognizedText = text;
    }

    final words = text.isEmpty
        ? <String>[]
        : text
            .split(RegExp(r'\s+'))
            .where((w) => w.isNotEmpty)
            .toList();

    final payload = SpeechTranscriptionPayload(
      text: text,
      words: words,
      confidence: result.confidence > 0 ? result.confidence : 0.85,
      isFinal: result.finalResult,
    );

    _transcriptionController.add(payload);
    onResultCallback?.call(payload);

    // Duolingo Parity: If the underlying ASR emits finalResult, evaluate immediately!
    if (result.finalResult && text.isNotEmpty) {
      _silenceTimer?.cancel();
      _maxListenTimer?.cancel();
      stopListening();
      return;
    }

    // Reset silence timer on partial results
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(milliseconds: 2500), () {
      if (_state == SpeechServiceState.listening) {
        stopListening();
      }
    });
  }

  /// Stop listening and transition to processing.
  Future<String> stopListening() async {
    _silenceTimer?.cancel();
    _maxListenTimer?.cancel();
    _soundLevelController.add(0.0);

    if (_state == SpeechServiceState.listening) {
      _setState(SpeechServiceState.processing);
    }

    try {
      await _speech.stop();
    } catch (_) {}

    // Release Bluetooth SCO voice routing and audio focus
    await SpeechLifecycleBridge.stopBluetoothSco();
    await SpeechLifecycleBridge.abandonAudioFocus();

    final text = _lastRecognizedText;
    return text;
  }

  /// Cancel listening immediately without processing and release native resources.
  Future<void> cancelListening() async {
    _silenceTimer?.cancel();
    _maxListenTimer?.cancel();
    _soundLevelController.add(0.0);
    _setState(SpeechServiceState.idle);

    try {
      await _speech.cancel();
    } catch (_) {}

    // Release Bluetooth SCO voice routing and audio focus
    await SpeechLifecycleBridge.stopBluetoothSco();
    await SpeechLifecycleBridge.abandonAudioFocus();
    await SpeechLifecycleBridge.destroyNativeRecognizer();
  }

  void _handleNativeError(SpeechRecognitionError error) {
    debugPrint('STT Native Error: ${error.errorMsg} (permanent: ${error.permanent})');
    _soundLevelController.add(0.0);

    final msg = error.errorMsg.toLowerCase();

    // Transient Android recognition events (natural pauses between words, initial silence, or non-fatal noise):
    // Follow the stable Oct 25 release behavior: log and DO NOT abort the active recording session.
    if (msg.contains('error_speech_timeout') ||
        msg.contains('timeout') ||
        msg.contains('error_no_match') ||
        msg.contains('no match') ||
        msg.contains('error_client')) {
      debugPrint('ℹ️ [STT] Transient speech event ignored ($msg); session continues listening.');
      return;
    }

    SpeechRecognitionErrorType errType = SpeechRecognitionErrorType.unknown;

    if (msg.contains('error_busy') || msg.contains('busy')) {
      errType = SpeechRecognitionErrorType.busy;
    } else if (msg.contains('network') || msg.contains('server')) {
      errType = SpeechRecognitionErrorType.network;
    } else if (msg.contains('permission')) {
      errType = SpeechRecognitionErrorType.permissionDenied;
    }

    _setState(SpeechServiceState.error);
    _errorController.add(errType);
  }

  void _handleNativeStatus(String status) {
    debugPrint('STT Native Status: $status');
    if (status == 'done' || status == 'notListening') {
      _soundLevelController.add(0.0);
      if (_state == SpeechServiceState.listening) {
        _setState(SpeechServiceState.processing);
      }
    }
  }

  void dispose() {
    _silenceTimer?.cancel();
    _maxListenTimer?.cancel();
    _stateController.close();
    _soundLevelController.close();
    _transcriptionController.close();
    _errorController.close();
  }
}
