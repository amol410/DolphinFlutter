import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphincoder/core/services/sound_effects_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SoundEffectsService sfx;

  setUpAll(() {
    const channel1 = MethodChannel('xyz.luan/audioplayers.global');
    const channel2 = MethodChannel('xyz.luan/audioplayers');
    const channelPath = MethodChannel('plugins.flutter.io/path_provider');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel1, (MethodCall methodCall) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel2, (MethodCall methodCall) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channelPath, (MethodCall methodCall) async => '.');

    sfx = SoundEffectsService.instance;
  });

  tearDown(() {
    sfx.dispose();
  });

  group('SoundEffectsService Unit Tests', () {
    test('singleton pattern returns the exact same instance', () {
      final sfx1 = SoundEffectsService();
      final sfx2 = SoundEffectsService.instance;
      expect(identical(sfx1, sfx2), isTrue);
      expect(identical(sfx1, sfx), isTrue);
    });

    test('init() completes cleanly without errors', () async {
      await expectLater(sfx.init(), completes);
    });

    test('playPop() executes without throwing exceptions', () async {
      await expectLater(sfx.playPop(), completes);
    });

    test('playCorrect() executes without throwing exceptions', () async {
      await expectLater(sfx.playCorrect(), completes);
    });

    test('playWrong() executes without throwing exceptions', () async {
      await expectLater(sfx.playWrong(), completes);
    });

    test('playFanfare() executes without throwing exceptions', () async {
      await expectLater(sfx.playFanfare(), completes);
    });

    test('dispose() cleans up and service can be re-initialized gracefully', () async {
      await sfx.init();
      sfx.dispose();
      await expectLater(sfx.playPop(), completes);
    });
  });
}
