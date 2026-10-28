import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphincoder/core/services/tts_service.dart';

// Test harness mirroring the Dual-Speed (Normal + Turtle) audio control row
Widget _buildDualSpeedAudioBar({
  required void Function(double speed) onPlayAudio,
  bool isPlaying = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Normal Speed Play Button
            GestureDetector(
              key: const ValueKey('normal_speed_button'),
              onTap: isPlaying ? null : () => onPlayAudio(1.0),
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0284C7),
                  border: Border.all(color: const Color(0xFF0369A1), width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF0369A1),
                      blurRadius: 0,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Slow (Turtle) Play Button
            GestureDetector(
              key: const ValueKey('turtle_speed_button'),
              onTap: isPlaying ? null : () => onPlayAudio(0.75),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF1F5F9),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFFCBD5E1),
                      blurRadius: 0,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🐢', style: TextStyle(fontSize: 24)),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

void main() {
  group('Turtle Speed Audio Dictation UI Tests', () {
    testWidgets('renders both Normal Speaker and Turtle Speed buttons with 3D tactile bevels', (tester) async {
      await tester.pumpWidget(_buildDualSpeedAudioBar(
        onPlayAudio: (_) {},
      ));

      // Normal button assertions
      final normalButton = find.byKey(const ValueKey('normal_speed_button'));
      expect(normalButton, findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

      final normalContainer = tester.widget<Container>(find.descendant(
        of: normalButton,
        matching: find.byType(Container),
      ));
      final normalDecoration = normalContainer.decoration as BoxDecoration;
      expect(normalDecoration.color, const Color(0xFF0284C7));
      expect(normalDecoration.boxShadow!.first.offset, const Offset(0, 4));
      expect(normalDecoration.boxShadow!.first.color, const Color(0xFF0369A1));

      // Turtle button assertions
      final turtleButton = find.byKey(const ValueKey('turtle_speed_button'));
      expect(turtleButton, findsOneWidget);
      expect(find.text('🐢'), findsOneWidget);

      final turtleContainer = tester.widget<Container>(find.descendant(
        of: turtleButton,
        matching: find.byType(Container),
      ));
      final turtleDecoration = turtleContainer.decoration as BoxDecoration;
      expect(turtleDecoration.color, const Color(0xFFF1F5F9));
      expect(turtleDecoration.boxShadow!.first.offset, const Offset(0, 3));
      expect(turtleDecoration.boxShadow!.first.color, const Color(0xFFCBD5E1));
    });

    testWidgets('tapping normal speaker button emits speed = 1.0 (maps to 0.48 speech rate)', (tester) async {
      double? receivedSpeed;
      await tester.pumpWidget(_buildDualSpeedAudioBar(
        onPlayAudio: (speed) {
          receivedSpeed = speed;
        },
      ));

      await tester.tap(find.byKey(const ValueKey('normal_speed_button')));
      await tester.pumpAndSettle();

      expect(receivedSpeed, equals(1.0));
      // Verify integration with TtsService.calculateSpeechRate
      final ttsRate = TtsService.calculateSpeechRate(receivedSpeed!);
      expect(ttsRate, closeTo(0.48, 0.001));
    });

    testWidgets('tapping turtle button emits speed = 0.75 (maps to 0.32 slowed down turtle speech rate)', (tester) async {
      double? receivedSpeed;
      await tester.pumpWidget(_buildDualSpeedAudioBar(
        onPlayAudio: (speed) {
          receivedSpeed = speed;
        },
      ));

      await tester.tap(find.byKey(const ValueKey('turtle_speed_button')));
      await tester.pumpAndSettle();

      expect(receivedSpeed, equals(0.75));
      // Verify integration with TtsService.calculateSpeechRate
      final ttsRate = TtsService.calculateSpeechRate(receivedSpeed!);
      expect(ttsRate, closeTo(0.32, 0.001));
      expect(ttsRate, lessThan(0.48));
    });

    testWidgets('buttons ignore taps when audio is actively playing', (tester) async {
      int tapCount = 0;
      await tester.pumpWidget(_buildDualSpeedAudioBar(
        onPlayAudio: (_) {
          tapCount++;
        },
        isPlaying: true,
      ));

      await tester.tap(find.byKey(const ValueKey('normal_speed_button')));
      await tester.tap(find.byKey(const ValueKey('turtle_speed_button')));
      await tester.pumpAndSettle();

      expect(tapCount, equals(0));
    });
  });
}
