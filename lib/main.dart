import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/ad_service.dart';
import 'core/services/tts_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Asynchronously pre-initialize native German TTS engine and AdMob SDK on boot
  TtsService().init();
  AdService().init();
  runApp(const ProviderScope(child: DolphinCoderApp()));
}
