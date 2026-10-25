import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphincoder/shared/widgets/tactile_game_button.dart';

void main() {
  group('TactileGameButton Widget Tests', () {
    testWidgets('renders button text and triggers onPressed callback on tap', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactileGameButton(
                text: 'CONTINUE TO MAP',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('CONTINUE TO MAP'), findsOneWidget);
      await tester.tap(find.text('CONTINUE TO MAP'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('renders loading spinner when isLoading is true', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactileGameButton(
                text: 'CONTINUE',
                isLoading: true,
                onPressed: null,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('CONTINUE'), findsNothing);
    });

    testWidgets('disabled button does not trigger callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: TactileGameButton(
                text: 'DISABLED',
                onPressed: null,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('DISABLED'));
      await tester.pumpAndSettle();

      expect(tapped, isFalse);
    });
  });
}
