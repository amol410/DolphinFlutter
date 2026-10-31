import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/ad_service.dart';
import 'core/services/analytics_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/tts_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Sub-second cold startup: render app UI immediately on frame 1 (< 400ms)
  runApp(const ProviderScope(child: DolphinCoderApp()));

  // Defer non-critical background services (Analytics, Notifications, TTS, AdMob) to post-render
  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.microtask(() async {
      await AnalyticsService().init();
      await NotificationService().init();
      TtsService().init();
      AdService().init();
    });
  });
}
