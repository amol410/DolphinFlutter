import 'package:flutter_test/flutter_test.dart';
import 'package:dolphincoder/features/gamification/data/lesson_stage_parser.dart';

void main() {
  group('LessonStageParser Blank & Unclicked Stage Filtering', () {
    test('extractValidStageTypes skips blank or incomplete challenge formats', () {
      final rawStages = [
        // Blank word_match
        {'type': 'word_match', 'pairs': []},
        // Blank listen_tap
        {'type': 'listen_tap', 'targetSentence': '', 'tokens': []},
        // Blank picture_select
        {'type': 'picture_select', 'options': []},
        // Blank sentence_builder
        {'type': 'sentence_builder', 'targetSentence': '', 'tokens': []},
        // Blank cloze_test
        {'type': 'cloze_test', 'sentence': '', 'blank': ''},
        // Blank type_word
        {'type': 'type_word', 'target': '', 'prompt': ''},
        // Blank dialogue_bubble
        {'type': 'dialogue_bubble', 'partnerMessage': '', 'options': []},
        // Blank listen_select
        {'type': 'listen_select', 'sentence': '', 'question': '', 'options': []},
        // Blank sprechen
        {'type': 'sprechen', 'prompt': ''},
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
          'type': 'picture_select',
          'prompt': 'Choose the apple',
          'options': [
            {'id': '1', 'text': 'der Apfel', 'imageUrl': 'apple.webp', 'isCorrect': true},
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
      expect(validTypes, ['word_match', 'picture_select', 'sentence_builder', 'sprechen']);
    });

    test('parseWordMatch validates non-empty pairs', () {
      expect(LessonStageParser.parseWordMatch({'pairs': []}), isNull);
      final valid = LessonStageParser.parseWordMatch({
        'pairs': [
          {'target': 'Danke', 'native': 'Thank you'},
          {'target': '   ', 'native': 'Invalid'},
        ]
      });
      expect(valid, isNotNull);
      expect(valid!.germanWords, ['Danke']);
      expect(valid.solutionPairs['Danke'], 'Thank you');
    });

    test('parseListenTap returns null when sentence and tokens are empty', () {
      expect(LessonStageParser.parseListenTap({'targetSentence': '', 'tokens': []}), isNull);
      final valid = LessonStageParser.parseListenTap({
        'targetSentence': 'Guten Morgen',
        'tokens': ['Guten', 'Morgen', 'Abend'],
      });
      expect(valid, isNotNull);
      expect(valid!.targetSentence, 'Guten Morgen');
    });

    test('parsePictureSelect validates options', () {
      expect(LessonStageParser.parsePictureSelect({'options': []}), isNull);
      final valid = LessonStageParser.parsePictureSelect({
        'prompt': 'Choose the apple',
        'targetWord': 'der Apfel',
        'options': [
          {'id': '1', 'text': 'Apfel', 'imageUrl': 'apple.webp', 'isCorrect': true},
        ],
      });
      expect(valid, isNotNull);
      expect(valid!.targetWord, 'der Apfel');
      expect(valid.options.length, 1);
    });

    test('parseSentenceBuilder returns null when target and tokens are empty', () {
      final parsed = LessonStageParser.parseSentenceBuilder({
        'type': 'sentence_builder',
        'targetSentence': '   ',
        'tokens': [],
      });
      expect(parsed, isNull);

      final valid = LessonStageParser.parseSentenceBuilder({
        'targetSentence': 'Ich bin Alex',
        'tokens': ['Ich', 'bin', 'Alex'],
      });
      expect(valid, isNotNull);
      expect(valid!.targetSentence, 'Ich bin Alex');
    });

    test('parseCloze returns null when sentence, blank, and options are empty', () {
      final parsed = LessonStageParser.parseCloze({
        'type': 'cloze_test',
        'sentence': '',
        'blank': '',
        'options': [],
      });
      expect(parsed, isNull);

      final valid = LessonStageParser.parseCloze({
        'sentence': 'Ich _____ aus Indien.',
        'blank': 'komme',
        'options': ['komme', 'wohne'],
      });
      expect(valid, isNotNull);
      expect(valid!.blank, 'komme');
    });

    test('parseTypeWord returns null when target and prompt are empty', () {
      final parsed = LessonStageParser.parseTypeWord({
        'type': 'type_word',
        'prompt': '',
        'target': '',
      });
      expect(parsed, isNull);

      final valid = LessonStageParser.parseTypeWord({
        'prompt': 'The coffee is hot.',
        'target': 'heiß',
      });
      expect(valid, isNotNull);
      expect(valid!.target, 'heiß');
    });

    test('parseDialogue returns null when message and options are empty', () {
      final parsed = LessonStageParser.parseDialogue({
        'type': 'dialogue_bubble',
        'partnerMessage': '',
        'options': [],
      });
      expect(parsed, isNull);

      final valid = LessonStageParser.parseDialogue({
        'partnerMessage': 'Hallo!',
        'options': [{'text': 'Guten Tag', 'isCorrect': true}],
      });
      expect(valid, isNotNull);
      expect(valid!.partnerMessage, 'Hallo!');
    });

    test('parseListenSelect returns null when sentence and question are empty', () {
      final parsed = LessonStageParser.parseListenSelect({
        'type': 'listen_select',
        'sentence': '',
        'question': '',
      });
      expect(parsed, isNull);

      final valid = LessonStageParser.parseListenSelect({
        'sentence': 'Zwei Kaffee, bitte.',
        'options': [{'text': 'Two coffees', 'isCorrect': true}],
      });
      expect(valid, isNotNull);
      expect(valid!.sentence, 'Zwei Kaffee, bitte.');
    });

    test('parseSprechen returns null when prompt is empty', () {
      final parsed = LessonStageParser.parseSprechen({
        'type': 'sprechen',
        'prompt': '   ',
      });
      expect(parsed, isNull);

      final valid = LessonStageParser.parseSprechen({
        'prompt': 'Guten Tag',
        'minAccuracy': 80,
      });
      expect(valid, isNotNull);
      expect(valid!.prompt, 'Guten Tag');
      expect(valid.minAccuracy, 80);
    });
  });
}
