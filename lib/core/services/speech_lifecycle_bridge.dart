import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge between Flutter and Android native platform for strict SpeechRecognizer,
/// Audio Focus, ACTION_AUDIO_BECOMING_NOISY, and Bluetooth SCO lifecycle management.
class SpeechEngineResolution {
  final bool isAvailable;
  final String tier; // 'tier1_google', 'tier2_oem', 'tier2_default', 'none'
  final String packageName;
  final String serviceName;
  final bool injected;

  const SpeechEngineResolution({
    required this.isAvailable,
    required this.tier,
    required this.packageName,
    required this.serviceName,
    required this.injected,
  });

  factory SpeechEngineResolution.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const SpeechEngineResolution(
        isAvailable: false,
        tier: 'none',
        packageName: '',
        serviceName: '',
        injected: false,
      );
    }
    return SpeechEngineResolution(
      isAvailable: map['isAvailable'] as bool? ?? false,
      tier: map['tier'] as String? ?? 'none',
      packageName: map['packageName'] as String? ?? '',
      serviceName: map['serviceName'] as String? ?? '',
      injected: map['injected'] as bool? ?? false,
    );
  }

  @override
  String toString() =>
      'SpeechEngineResolution(tier: $tier, package: $packageName, isAvailable: $isAvailable, injected: $injected)';
}

class SpeechLifecycleBridge {
  static const MethodChannel _channel =
      MethodChannel('com.dolphincoder.lms/speech_lifecycle');

  static final Set<VoidCallback> _onAudioBecomingNoisyListeners = {};
  static final Set<VoidCallback> _onAudioFocusLostListeners = {};
  static final Set<VoidCallback> _onAudioFocusGainedListeners = {};
  static bool _listenersInitialized = false;
  static SpeechEngineResolution? _lastResolution;
  static SpeechEngineResolution? get lastResolution => _lastResolution;

  static void _ensureMethodCallHandler() {
    if (!_listenersInitialized) {
      _listenersInitialized = true;
      _channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onAudioBecomingNoisy':
            debugPrint('🎧 [SpeechLifecycleBridge] Headphone unplugged: ACTION_AUDIO_BECOMING_NOISY received');
            for (final listener in List.of(_onAudioBecomingNoisyListeners)) {
              try { listener(); } catch (_) {}
            }
            break;
          case 'onAudioFocusLost':
            debugPrint('🔇 [SpeechLifecycleBridge] Audio focus lost (phone call/alarm): pausing lesson audio');
            for (final listener in List.of(_onAudioFocusLostListeners)) {
              try { listener(); } catch (_) {}
            }
            break;
          case 'onAudioFocusGained':
            debugPrint('🔊 [SpeechLifecycleBridge] Audio focus regained');
            for (final listener in List.of(_onAudioFocusGainedListeners)) {
              try { listener(); } catch (_) {}
            }
            break;
        }
      });
    }
  }

  /// Subscribes native lifecycle callbacks with automatic multicast routing and returns an unsubscribe token.
  static VoidCallback subscribeAudioLifecycle({
    VoidCallback? onAudioBecomingNoisy,
    VoidCallback? onAudioFocusLost,
    VoidCallback? onAudioFocusGained,
  }) {
    if (onAudioBecomingNoisy != null) _onAudioBecomingNoisyListeners.add(onAudioBecomingNoisy);
    if (onAudioFocusLost != null) _onAudioFocusLostListeners.add(onAudioFocusLost);
    if (onAudioFocusGained != null) _onAudioFocusGainedListeners.add(onAudioFocusGained);

    _ensureMethodCallHandler();

    return () {
      if (onAudioBecomingNoisy != null) _onAudioBecomingNoisyListeners.remove(onAudioBecomingNoisy);
      if (onAudioFocusLost != null) _onAudioFocusLostListeners.remove(onAudioFocusLost);
      if (onAudioFocusGained != null) _onAudioFocusGainedListeners.remove(onAudioFocusGained);
    };
  }

  /// Register native lifecycle callbacks (Headphone unplug, phone call, alarm interruption)
  static void registerAudioLifecycleListeners({
    VoidCallback? onAudioBecomingNoisy,
    VoidCallback? onAudioFocusLost,
    VoidCallback? onAudioFocusGained,
  }) {
    subscribeAudioLifecycle(
      onAudioBecomingNoisy: onAudioBecomingNoisy,
      onAudioFocusLost: onAudioFocusLost,
      onAudioFocusGained: onAudioFocusGained,
    );
  }

  /// Calls native Android Activity to forcefully cancel and destroy
  /// the underlying android.speech.SpeechRecognizer instance and nullify its reference.
  static Future<void> destroyNativeRecognizer() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('destroyRecognizer');
      debugPrint('🛡️ [SpeechLifecycleBridge] Native SpeechRecognizer destroyed and nullified');
    } catch (e) {
      debugPrint('ℹ️ [SpeechLifecycleBridge] destroyNativeRecognizer note: $e');
    }
  }

  /// Resolves and prepares the optimal speech recognition engine across 3 Tiers:
  /// - Tier 1: Try Google Speech Services (com.google.android.googlequicksearchbox)
  /// - Tier 2: Catch & Fallback to OEM Engine (Samsung, Xiaomi, Huawei, etc., skipping dummy TTS)
  /// - Tier 3: Pedagogical Safety Net if no speech engine is available
  static Future<SpeechEngineResolution> ensureOptimalSpeechEngine() async {
    if (!Platform.isAndroid) {
      return const SpeechEngineResolution(
        isAvailable: true,
        tier: 'ios_native',
        packageName: 'apple.speech',
        serviceName: '',
        injected: false,
      );
    }
    try {
      final res = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('ensureOptimalSpeechEngine');
      _lastResolution = SpeechEngineResolution.fromMap(res);
      debugPrint('🎙️ [SpeechLifecycleBridge] $_lastResolution');
      return _lastResolution!;
    } catch (e) {
      debugPrint('⚠️ [SpeechLifecycleBridge] ensureOptimalSpeechEngine error: $e');
      _lastResolution = const SpeechEngineResolution(
        isAvailable: false,
        tier: 'none',
        packageName: '',
        serviceName: '',
        injected: false,
      );
      return _lastResolution!;
    }
  }

  /// Verifies if SpeechRecognizer is available on the device via native Android API.
  static Future<bool> isRecognitionAvailable() async {
    if (!Platform.isAndroid) return true;
    try {
      final resolution = await ensureOptimalSpeechEngine();
      return resolution.isAvailable;
    } catch (e) {
      debugPrint('⚠️ [SpeechLifecycleBridge] isRecognitionAvailable error: $e');
      return false;
    }
  }

  /// Checks if a Bluetooth headset with microphone is connected.
  static Future<bool> isBluetoothHeadsetConnected() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? connected =
          await _channel.invokeMethod<bool>('isBluetoothHeadsetConnected');
      return connected ?? false;
    } catch (e) {
      debugPrint('⚠️ [SpeechLifecycleBridge] isBluetoothHeadsetConnected error: $e');
      return false;
    }
  }

  /// Starts Bluetooth SCO mode for bidirectional earbud voice recording (AirPods, Galaxy Buds).
  static Future<bool> startBluetoothSco() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? started =
          await _channel.invokeMethod<bool>('startBluetoothSco');
      return started ?? false;
    } catch (e) {
      debugPrint('⚠️ [SpeechLifecycleBridge] startBluetoothSco error: $e');
      return false;
    }
  }

  /// Stops Bluetooth SCO mode and restores normal media mode.
  static Future<void> stopBluetoothSco() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopBluetoothSco');
    } catch (e) {
      debugPrint('ℹ️ [SpeechLifecycleBridge] stopBluetoothSco note: $e');
    }
  }

  /// Requests transient audio focus from Android system.
  static Future<bool> requestAudioFocus() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? granted =
          await _channel.invokeMethod<bool>('requestAudioFocus');
      return granted ?? true;
    } catch (e) {
      return true;
    }
  }

  /// Abandons audio focus.
  static Future<void> abandonAudioFocus() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('abandonAudioFocus');
    } catch (_) {}
  }
}
