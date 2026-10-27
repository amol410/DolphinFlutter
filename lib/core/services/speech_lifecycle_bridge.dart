import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge between Flutter and Android native platform for strict SpeechRecognizer,
/// Audio Focus, ACTION_AUDIO_BECOMING_NOISY, and Bluetooth SCO lifecycle management.
class SpeechLifecycleBridge {
  static const MethodChannel _channel =
      MethodChannel('com.dolphincoder.lms/speech_lifecycle');

  static VoidCallback? _onAudioBecomingNoisy;
  static VoidCallback? _onAudioFocusLost;
  static VoidCallback? _onAudioFocusGained;
  static bool _listenersInitialized = false;

  /// Register native lifecycle callbacks (Headphone unplug, phone call, alarm interruption)
  static void registerAudioLifecycleListeners({
    VoidCallback? onAudioBecomingNoisy,
    VoidCallback? onAudioFocusLost,
    VoidCallback? onAudioFocusGained,
  }) {
    _onAudioBecomingNoisy = onAudioBecomingNoisy;
    _onAudioFocusLost = onAudioFocusLost;
    _onAudioFocusGained = onAudioFocusGained;

    if (!_listenersInitialized) {
      _listenersInitialized = true;
      _channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onAudioBecomingNoisy':
            debugPrint('🎧 [SpeechLifecycleBridge] Headphone unplugged: ACTION_AUDIO_BECOMING_NOISY received');
            _onAudioBecomingNoisy?.call();
            break;
          case 'onAudioFocusLost':
            debugPrint('🔇 [SpeechLifecycleBridge] Audio focus lost (phone call/alarm): pausing lesson audio');
            _onAudioFocusLost?.call();
            break;
          case 'onAudioFocusGained':
            debugPrint('🔊 [SpeechLifecycleBridge] Audio focus regained');
            _onAudioFocusGained?.call();
            break;
        }
      });
    }
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

  /// Verifies if SpeechRecognizer is available on the device via native Android API.
  static Future<bool> isRecognitionAvailable() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool? available =
          await _channel.invokeMethod<bool>('isRecognitionAvailable');
      return available ?? false;
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
