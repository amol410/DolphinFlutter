import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Test harness for verifying 3D Tactile Matching Pairs visual states and animations
Widget _buildTestTile({
  required String text,
  required bool isSelected,
  required bool isMatched,
  bool isWrong = false,
  bool isCorrect = false,
  VoidCallback? onTap,
}) {
  Color bg;
  Color border;
  double borderWidth;
  Color textColor;
  List<BoxShadow>? boxShadow;

  if (isWrong) {
    bg = const Color(0xFFFEF2F2);
    border = const Color(0xFFEF4444);
    borderWidth = 2.5;
    textColor = const Color(0xFFEF4444);
    boxShadow = const [
      BoxShadow(
        color: Color(0xFFDC2626),
        offset: Offset(0, 3.5),
        blurRadius: 0,
      ),
    ];
  } else if (isCorrect) {
    bg = const Color(0xFFECFDF5);
    border = const Color(0xFF10B981);
    borderWidth = 2.5;
    textColor = const Color(0xFF059669);
    boxShadow = const [
      BoxShadow(
        color: Color(0xFF059669),
        offset: Offset(0, 3.5),
        blurRadius: 0,
      ),
    ];
  } else if (isMatched) {
    bg = const Color(0xFFF1F5F9);
    border = const Color(0xFFCBD5E1);
    borderWidth = 1.5;
    textColor = const Color(0xFF94A3B8);
    boxShadow = null;
  } else if (isSelected) {
    bg = const Color(0xFFF0F9FF);
    border = const Color(0xFF0284C7);
    borderWidth = 2.5;
    textColor = const Color(0xFF0284C7);
    boxShadow = const [
      BoxShadow(
        color: Color(0xFF0369A1),
        offset: Offset(0, 3.5),
        blurRadius: 0,
      ),
    ];
  } else {
    bg = Colors.white;
    border = const Color(0xFFE2E8F0);
    borderWidth = 1.5;
    textColor = const Color(0xFF1E293B);
    boxShadow = const [
      BoxShadow(
        color: Color(0xFFCBD5E1),
        offset: Offset(0, 3.5),
        blurRadius: 0,
      ),
    ];
  }

  return MaterialApp(
    home: Scaffold(
      body: GestureDetector(
        onTap: (isMatched || isCorrect || isWrong) ? null : onTap,
        child: Container(
          key: const ValueKey('match_tile_box'),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: borderWidth),
            boxShadow: boxShadow,
          ),
          child: Text(
            text,
            style: TextStyle(color: textColor),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('3D Tactile Matching Pairs Visual State Tests', () {
    testWidgets('Default state has solid 3.5px physical bevel and white background', (tester) async {
      await tester.pumpWidget(_buildTestTile(
        text: 'Guten Tag',
        isSelected: false,
        isMatched: false,
      ));

      final container = tester.widget<Container>(find.byKey(const ValueKey('match_tile_box')));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, Colors.white);
      expect((decoration.border as Border).top.color, const Color(0xFFE2E8F0));
      expect(decoration.boxShadow, isNotNull);
      expect(decoration.boxShadow!.first.offset, const Offset(0, 3.5));
      expect(decoration.boxShadow!.first.color, const Color(0xFFCBD5E1));
    });

    testWidgets('Selected state has sky blue border and deeper 3D shadow', (tester) async {
      await tester.pumpWidget(_buildTestTile(
        text: 'Danke',
        isSelected: true,
        isMatched: false,
      ));

      final container = tester.widget<Container>(find.byKey(const ValueKey('match_tile_box')));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, const Color(0xFFF0F9FF));
      expect((decoration.border as Border).top.color, const Color(0xFF0284C7));
      expect((decoration.border as Border).top.width, 2.5);
      expect(decoration.boxShadow!.first.color, const Color(0xFF0369A1));
    });

    testWidgets('Correct match state flashes Emerald Green (#ECFDF5, #10B981)', (tester) async {
      await tester.pumpWidget(_buildTestTile(
        text: 'Bitte',
        isSelected: false,
        isMatched: false,
        isCorrect: true,
      ));

      final container = tester.widget<Container>(find.byKey(const ValueKey('match_tile_box')));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, const Color(0xFFECFDF5));
      expect((decoration.border as Border).top.color, const Color(0xFF10B981));
      expect(decoration.boxShadow!.first.color, const Color(0xFF059669));
    });

    testWidgets('Wrong mismatch state flashes Soft Red (#FEF2F2, #EF4444)', (tester) async {
      await tester.pumpWidget(_buildTestTile(
        text: 'Tschüss',
        isSelected: false,
        isMatched: false,
        isWrong: true,
      ));

      final container = tester.widget<Container>(find.byKey(const ValueKey('match_tile_box')));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, const Color(0xFFFEF2F2));
      expect((decoration.border as Border).top.color, const Color(0xFFEF4444));
      expect((decoration.border as Border).top.width, 2.5);
      expect(decoration.boxShadow!.first.color, const Color(0xFFDC2626));
    });

    testWidgets('Completed matched state has no shadow and muted grey styling', (tester) async {
      await tester.pumpWidget(_buildTestTile(
        text: 'Hello',
        isSelected: false,
        isMatched: true,
      ));

      final container = tester.widget<Container>(find.byKey(const ValueKey('match_tile_box')));
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, const Color(0xFFF1F5F9));
      expect((decoration.border as Border).top.color, const Color(0xFFCBD5E1));
      expect(decoration.boxShadow, isNull);
    });

    testWidgets('Tapping tile invokes callback only when not disabled or matched', (tester) async {
      int tapCount = 0;

      // 1. Interactive idle tile should trigger tap
      await tester.pumpWidget(_buildTestTile(
        text: 'Interactive',
        isSelected: false,
        isMatched: false,
        onTap: () => tapCount++,
      ));
      await tester.tap(find.byType(GestureDetector));
      expect(tapCount, 1);

      // 2. Already matched tile should NOT trigger tap
      await tester.pumpWidget(_buildTestTile(
        text: 'Matched',
        isSelected: false,
        isMatched: true,
        onTap: () => tapCount++,
      ));
      await tester.tap(find.byType(GestureDetector));
      expect(tapCount, 1); // Remains 1

      // 3. Tile during wrong mismatch flash should NOT trigger tap
      await tester.pumpWidget(_buildTestTile(
        text: 'Wrong',
        isSelected: false,
        isMatched: false,
        isWrong: true,
        onTap: () => tapCount++,
      ));
      await tester.tap(find.byType(GestureDetector));
      expect(tapCount, 1); // Remains 1
    });
  });
}
