import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphincoder/features/gamification/data/models/gamification_models.dart';

void main() {
  group('Project Slipstream - Flutter Client Acceleration Tests', () {
    test('1. JSON Path Nodes Serialization & Deserialization Fidelity', () {
      const sampleNodes = [
        PathNodeModel(
          index: 0,
          title: 'Unit 1 Lesson 1',
          subtitle: 'Greetings',
          type: 'lesson',
          status: 'completed',
          unitNumber: 1,
          unitTitle: 'First Steps',
          sectionNumber: 1,
          sectionTitle: 'Rookie',
          sectionUnitNumber: 1,
          colorHex: '#1CB0F6',
          xpReward: 15,
          pearlsReward: 5,
        ),
        PathNodeModel(
          index: 1,
          title: 'Unit 1 Lesson 2',
          subtitle: 'Farewells',
          type: 'lesson',
          status: 'available',
          unitNumber: 1,
          unitTitle: 'First Steps',
          sectionNumber: 1,
          sectionTitle: 'Rookie',
          sectionUnitNumber: 1,
          colorHex: '#1CB0F6',
          xpReward: 15,
          pearlsReward: 5,
        ),
      ];

      // Simulate off-thread isolate encoding
      final rawList = sampleNodes.map((n) => n.toJson()).toList();
      final jsonString = jsonEncode(rawList);

      expect(jsonString, isNotEmpty);

      // Simulate off-thread isolate decoding
      final dynamic decoded = jsonDecode(jsonString);
      expect(decoded, isA<List>());

      final parsedList = (decoded as List)
          .whereType<Map<String, dynamic>>()
          .map((item) => PathNodeModel.fromJson(item))
          .toList();

      expect(parsedList.length, equals(2));
      expect(parsedList[0].title, equals('Unit 1 Lesson 1'));
      expect(parsedList[0].status, equals('completed'));
      expect(parsedList[1].title, equals('Unit 1 Lesson 2'));
      expect(parsedList[1].status, equals('available'));
    });

    test('2. Lookahead Window Merging Logic', () {
      final initialWindow = [
        const PathNodeModel(
          index: 0,
          title: 'Lesson 0',
          subtitle: 'Intro',
          type: 'lesson',
          status: 'completed',
          unitNumber: 1,
        ),
        const PathNodeModel(
          index: 1,
          title: 'Lesson 1',
          subtitle: 'Basics',
          type: 'lesson',
          status: 'available',
          unitNumber: 1,
        ),
      ];

      final nextLookaheadWindow = [
        const PathNodeModel(
          index: 1, // Fresh sync updates status of lesson 1
          title: 'Lesson 1',
          subtitle: 'Basics',
          type: 'lesson',
          status: 'completed',
          unitNumber: 1,
        ),
        const PathNodeModel(
          index: 2, // New node appended
          title: 'Lesson 2',
          subtitle: 'Expressions',
          type: 'lesson',
          status: 'available',
          unitNumber: 2,
        ),
        const PathNodeModel(
          index: 3, // New node appended
          title: 'Lesson 3',
          subtitle: 'Review',
          type: 'chest',
          status: 'locked',
          unitNumber: 2,
        ),
      ];

      // Slipstream merge algorithm
      final mergedMap = {for (final n in initialWindow) n.index: n};
      for (final n in nextLookaheadWindow) {
        mergedMap[n.index] = n;
      }
      final mergedList = mergedMap.values.toList()..sort((a, b) => a.index.compareTo(b.index));

      expect(mergedList.length, equals(4));
      expect(mergedList[0].index, equals(0));
      expect(mergedList[1].index, equals(1));
      expect(mergedList[1].status, equals('completed')); // Updated
      expect(mergedList[2].index, equals(2));
      expect(mergedList[3].index, equals(3));
    });

    test('3. Lookahead Window Bounds Calculation', () {
      int loadedMaxUnit = 4;
      final nextStart = loadedMaxUnit + 1;
      final nextEnd = loadedMaxUnit + 3;

      expect(nextStart, equals(5));
      expect(nextEnd, equals(7));

      // After loading window 5..7
      loadedMaxUnit = nextEnd;
      final subsequentStart = loadedMaxUnit + 1;
      final subsequentEnd = loadedMaxUnit + 3;

      expect(subsequentStart, equals(8));
      expect(subsequentEnd, equals(10));
    });
  });
}
