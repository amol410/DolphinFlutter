import 'package:flutter_test/flutter_test.dart';
import 'package:dolphincoder/features/gamification/data/lesson_stage_parser.dart';

void main() {
  group('LessonStageParser Blank & Unclicked Stage Filtering', () {
    test('extractValidStageTypes skips blank or incomplete challenge formats', () {
      final rawStages = [
        // Blank word_match
        {'type': 'word_match', 'pairs': []},
        // Blank sentence_builder
        {'type': 'sentence_builder', 'targetSentence': '', 'tokens': []},
        // Blank cloze_test
        {'type': 'cloze_test', 'sentence': '', 'blank': ''},
        // Blank sprechen
        {'type': 'sprechen', 'prompt': ''},
        // Blank type_word
        {'type': 'type_word', 'target': '', 'prompt': ''},
        // Blank dialogue_bubble
        {'type': 'dialogue_bubble', 'partnerMessage': '', 'options': []},
        // Blank listen_select
        {'type': 'listen_select', 'sentence': '', 'options': []},
      ];

      final validTypes = LessonStageParser.extractValidStageTypes(rawStages);
      expect(validTypes, isEmpty);
    });

    test('extractValidStageTypes retains active and valid challenge formats', () {
      final rawStages = [
        {
          'type': 'word_match',
          'pairs': [
            {'target': 'Hallo', 'native': 'Hello'},
          ],
        },
        {
          'type': 'sentence_builder',
          'prompt': 'Translate hello',
          'targetSentence': 'Hallo wie gehts',
          'tokens': ['Hallo', 'wie', 'gehts'],
        },
        {
          'type': 'sprechen',
          'prompt': 'Guten Tag',
        },
      ];

      final validTypes = LessonStageParser.extractValidStageTypes(rawStages);
      expect(validTypes, ['word_match', 'sentence_builder', 'sprechen']);
    });

    test('parseSentenceBuilder returns null when target and tokens are empty', () {
      final parsed = LessonStageParser.parseSentenceBuilder({
        'type': 'sentence_builder',
        'targetSentence': '   ',
        'tokens': [],
      });
      expect(parsed, isNull);
    });

    test('parseCloze returns null when sentence, blank, and options are empty', () {
      final parsed = LessonStageParser.parseCloze({
        'type': 'cloze_test',
        'sentence': '',
        'blank': '',
        'options': [],
      });
      expect(parsed, isNull);
    });

    test('parseSprechen returns null when prompt is empty', () {
      final parsed = LessonStageParser.parseSprechen({
        'type': 'sprechen',
        'prompt': '   ',
      });
      expect(parsed, isNull);
    });
  });
}
