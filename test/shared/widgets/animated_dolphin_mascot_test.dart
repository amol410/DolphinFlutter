import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphincoder/shared/widgets/animated_dolphin_mascot.dart';

void main() {
  group('AnimatedDolphinMascot Widget & WebP Asset Tests', () {
    testWidgets('Renders AnimatedDolphinMascot with default waving pose', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedDolphinMascot(size: 110),
            ),
          ),
        ),
      );

      expect(find.byType(AnimatedDolphinMascot), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      final image = tester.widget<Image>(find.byType(Image));
      final assetImage = image.image as AssetImage;
      expect(assetImage.assetName, equals('assets/images/mascot/dolphin_waving.webp'));
      expect(image.width, equals(110.0));
      expect(image.height, equals(110.0));
    });

    testWidgets('Renders all 10 distinct MascotPose values with correct WebP assets', (tester) async {
      final poseAssetMap = {
        MascotPose.jump: 'assets/images/mascot/dolphin_jump.webp',
        MascotPose.reading: 'assets/images/mascot/dolphin_reading.webp',
        MascotPose.waving: 'assets/images/mascot/dolphin_waving.webp',
        MascotPose.graduation: 'assets/images/mascot/dolphin_graduation.webp',
        MascotPose.thinking: 'assets/images/mascot/dolphin_thinking.webp',
        MascotPose.celebrate: 'assets/images/mascot/dolphin_celebrate.webp',
        MascotPose.letters: 'assets/images/mascot/dolphin_letters.webp',
        MascotPose.flag: 'assets/images/mascot/dolphin_flag.webp',
        MascotPose.headphones: 'assets/images/mascot/dolphin_headphones.webp',
        MascotPose.backpack: 'assets/images/mascot/dolphin_backpack.webp',
      };

      for (final entry in poseAssetMap.entries) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedDolphinMascot(
                  size: 120,
                  pose: entry.key,
                  animate: false,
                ),
              ),
            ),
          ),
        );

        final image = tester.widget<Image>(find.byType(Image));
        final assetImage = image.image as AssetImage;
        expect(
          assetImage.assetName,
          equals(entry.value),
          reason: 'Pose ${entry.key} must resolve to ${entry.value}',
        );
      }
    });

    testWidgets('Triggers onTap callback and responds to tap bounce', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedDolphinMascot(
                size: 100,
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AnimatedDolphinMascot));
      await tester.pump(const Duration(milliseconds: 100));

      expect(tapped, isTrue);
    });

    testWidgets('isCelebrating overrides pose to celebrate', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedDolphinMascot(
                size: 100,
                pose: MascotPose.reading,
                isCelebrating: true,
                animate: false,
              ),
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      final assetImage = image.image as AssetImage;
      expect(assetImage.assetName, equals('assets/images/mascot/dolphin_celebrate.webp'));
    });

    testWidgets('isListening resolves to headphones pose', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: AnimatedDolphinMascot(
                size: 100,
                isListening: true,
                animate: false,
              ),
            ),
          ),
        ),
      );

      final image = tester.widget<Image>(find.byType(Image));
      final assetImage = image.image as AssetImage;
      expect(assetImage.assetName, equals('assets/images/mascot/dolphin_headphones.webp'));
    });
  });
}
