import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridge between Flutter and Android native platform for strict SpeechRecognizer
/// lifecycle management to prevent system-wide audio resource leaks.
class SpeechLifecycleBridge {
  static const MethodChannel _channel =
      MethodChannel('com.dolphincoder.lms/speech_lifecycle');

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
}
