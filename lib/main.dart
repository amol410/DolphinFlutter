import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/tts_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Asynchronously pre-initialize native German TTS engine on boot
  TtsService().init();
  runApp(const ProviderScope(child: DolphinCoderApp()));
}
