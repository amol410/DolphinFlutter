import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/ad_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Asynchronously pre-initialize Firebase Analytics & Crashlytics, Notifications, TTS, and AdMob
  await AnalyticsService().init();
  await NotificationService().init();
  TtsService().init();
  AdService().init();
  runApp(const ProviderScope(child: DolphinCoderApp()));
}
