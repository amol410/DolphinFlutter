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
    // Ads start on their own timer, independent of the other services. Notification
    // init awaits the Android 13+ permission prompt, which previously held ads back
    // until the user answered it (causing "Ad is preparing" on early taps).
    Future.delayed(const Duration(seconds: 1), () => AdService().init());

    Future.microtask(() async {
      await AnalyticsService().init();
      await NotificationService().init();
      TtsService().init();
    });
  });
}
