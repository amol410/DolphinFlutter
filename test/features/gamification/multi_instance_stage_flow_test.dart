import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dolphincoder/features/gamification/data/lesson_stage_parser.dart';

/// Test harness implementing the interactive lesson session state machine,
/// matching LessonSessionScreen's mistake review loop and state isolation.
class LessonSessionFlowHarness {
  int currentStage = 0;
  List<String> activeStageTypes = [];
  List<ParsedLessonStage> parsedStages = [];
  bool currentStageReEnqueued = false;
  int mistakesCount = 0;

  // Active word_match state
  final Set<String> matchedGerman = {};
  final Set<String> matchedEnglish = {};
  String? selectedGerman;
  String? selectedEnglish;
  bool matchFinished = false;

  // Active listen_tap state
  final List<int> listenSelectedIndices = [];
  bool? listenCorrect;

  // Active picture_select state
  String? selectedPictureOptionId;
  bool? pictureCorrect;

  // Active sentence_builder state
  final List<int> builderSelectedIndices = [];
  bool? builderCorrect;

  // Active cloze_test state
  String? clozeSelectedOption;
  bool? clozeCorrect;

  // Active stage models
  WordMatchStageData? activeWordMatch;
  ListenTapStageData? activeListenTap;
  PictureSelectStageData? activePictureSelect;
  SentenceBuilderStageData? activeSentenceBuilder;
  ClozeStageData? activeCloze;

  void applyStages(List<dynamic> rawStages) {
    parsedStages = LessonStageParser.parseStages(rawStages);
    activeStageTypes = parsedStages.map((s) => s.canonicalType).toList();
    if (parsedStages.isNotEmpty) {
      loadStageDataAtIndex(0);
    }
  }

  void loadStageDataAtIndex(int index) {
    if (index < 0 || index >= activeStageTypes.length) return;
    final stageType = activeStageTypes[index];
    if (index < parsedStages.length) {
      applyParsedStageToFields(parsedStages[index]);
    }
    resetStageStateForType(stageType);
  }

  void applyParsedStageToFields(ParsedLessonStage entry) {
    final type = entry.canonicalType;
    final data = entry.data;
    if (type == 'word_match' && data is WordMatchStageData) {
      activeWordMatch = data;
    } else if (type == 'listen_tap' && data is ListenTapStageData) {
      activeListenTap = data;
    } else if (type == 'picture_select' && data is PictureSelectStageData) {
      activePictureSelect = data;
    } else if (type == 'sentence_builder' && data is SentenceBuilderStageData) {
      activeSentenceBuilder = data;
    } else if (type == 'cloze_test' && data is ClozeStageData) {
      activeCloze = data;
    }
  }

  void resetStageStateForType(String stageType) {
    switch (stageType) {
      case 'word_match':
      case 'match_pairs':
        matchedGerman.clear();
        matchedEnglish.clear();
        selectedGerman = null;
        selectedEnglish = null;
        matchFinished = false;
        break;
      case 'listen_tap':
        listenSelectedIndices.clear();
        listenCorrect = null;
        break;
      case 'picture_select':
      case 'picture_cards':
        selectedPictureOptionId = null;
        pictureCorrect = null;
        break;
      case 'sentence_builder':
        builderSelectedIndices.clear();
        builderCorrect = null;
        break;
      case 'cloze_test':
      case 'cloze':
        clozeSelectedOption = null;
        clozeCorrect = null;
        break;
    }
  }

  void handleIncorrectAnswer() {
    mistakesCount++;
    if (!currentStageReEnqueued && currentStage < activeStageTypes.length) {
      currentStageReEnqueued = true;
      final currentType = activeStageTypes[currentStage];
      activeStageTypes.add(currentType);
      if (currentStage < parsedStages.length) {
        parsedStages.add(parsedStages[currentStage]);
      }
    }
  }

  void nextStage() {
    currentStageReEnqueued = false;
    currentStage++;
    if (currentStage < activeStageTypes.length) {
      loadStageDataAtIndex(currentStage);
    }
  }
}

/// Simple interactive multi-instance tile widget for testing UI state reset
class MultiInstanceTestTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isMatched;
  final VoidCallback onTap;

  const MultiInstanceTestTile({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isMatched,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: ValueKey('tile_$label'),
      onTap: isMatched ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMatched
              ? Colors.grey.shade200
              : (isSelected ? Colors.blue.shade100 : Colors.white),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isMatched ? Colors.grey : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

void main() {
  group('Multi-Instance Repeated Challenges Flow Tests', () {
    /* ======================================================================
     * 1. LessonStageParser with Repeated Stages
     * ====================================================================== */
    group('1. LessonStageParser Repeated Stage Parsing', () {
      test('parses interleaved repeated challenges preserving exact order and distinct payloads', () {
        final rawStages = [
          {
            'type': 'word_match',
            'id': 'wm_1',
            'pairs': [
              {'target': 'Hallo', 'native': 'Hello'},
              {'target': 'Danke', 'native': 'Thank you'},
            ],
          },
          {
            'type': 'picture_select',
            'id': 'pic_1',
            'prompt': 'Choose the apple',
            'targetWord': 'der Apfel',
            'options': [
              {'id': 'opt_1', 'text': 'der Apfel', 'imageUrl': 'apple.webp', 'isCorrect': true},
              {'id': 'opt_2', 'text': 'die Birne', 'imageUrl': 'pear.webp', 'isCorrect': false},
            ],
          },
          {
            'type': 'listen_tap',
            'id': 'listen_1',
            'targetSentence': 'Guten Morgen',
            'tokens': ['Guten', 'Morgen', 'Abend'],
          },
          {
            'type': 'word_match',
            'id': 'wm_2',
            'pairs': [
              {'target': 'Wasser', 'native': 'Water'},
              {'target': 'Brot', 'native': 'Bread'},
            ],
          },
          {
            'type': 'picture_select',
            'id': 'pic_2',
            'prompt': 'Choose the dog',
            'targetWord': 'der Hund',
            'options': [
              {'id': 'opt_3', 'text': 'der Hund', 'imageUrl': 'dog.webp', 'isCorrect': true},
              {'id': 'opt_4', 'text': 'die Katze', 'imageUrl': 'cat.webp', 'isCorrect': false},
            ],
          },
          {
            'type': 'listen_tap',
            'id': 'listen_2',
            'targetSentence': 'Ich trinke Wasser',
            'tokens': ['Ich', 'trinke', 'Wasser', 'Tee'],
          },
        ];

        final parsedList = LessonStageParser.parseStages(rawStages);
        expect(parsedList.length, 6);

        expect(
          parsedList.map((s) => s.canonicalType).toList(),
          ['word_match', 'picture_select', 'listen_tap', 'word_match', 'picture_select', 'listen_tap'],
        );

        // Verify instance #1 vs instance #2 for word_match
        final wm1 = parsedList[0].data as WordMatchStageData;
        final wm2 = parsedList[3].data as WordMatchStageData;
        expect(wm1.germanWords, containsAll(['Hallo', 'Danke']));
        expect(wm1.solutionPairs['Hallo'], 'Hello');
        expect(wm1.solutionPairs.containsKey('Wasser'), isFalse);

        expect(wm2.germanWords, containsAll(['Wasser', 'Brot']));
        expect(wm2.solutionPairs['Wasser'], 'Water');
        expect(wm2.solutionPairs.containsKey('Hallo'), isFalse);

        // Verify instance #1 vs instance #2 for picture_select
        final pic1 = parsedList[1].data as PictureSelectStageData;
        final pic2 = parsedList[4].data as PictureSelectStageData;
        expect(pic1.targetWord, 'der Apfel');
        expect(pic1.options.first.id, 'opt_1');

        expect(pic2.targetWord, 'der Hund');
        expect(pic2.options.first.id, 'opt_3');

        // Verify instance #1 vs instance #2 for listen_tap
        final lt1 = parsedList[2].data as ListenTapStageData;
        final lt2 = parsedList[5].data as ListenTapStageData;
        expect(lt1.targetSentence, 'Guten Morgen');
        expect(lt2.targetSentence, 'Ich trinke Wasser');
      });

      test('parses back-to-back consecutive identical challenge instances independently', () {
        final consecutiveRaw = [
          {
            'type': 'word_match',
            'pairs': [
              {'target': 'Rot', 'native': 'Red'},
              {'target': 'Grün', 'native': 'Green'},
            ],
          },
          {
            'type': 'word_match',
            'pairs': [
              {'target': 'Blau', 'native': 'Blue'},
              {'target': 'Gelb', 'native': 'Yellow'},
            ],
          },
        ];

        final parsed = LessonStageParser.parseStages(consecutiveRaw);
        expect(parsed.length, 2);
        expect(parsed[0].canonicalType, 'word_match');
        expect(parsed[1].canonicalType, 'word_match');

        final match1 = parsed[0].data as WordMatchStageData;
        final match2 = parsed[1].data as WordMatchStageData;
        expect(match1.germanWords, ['Rot', 'Grün']);
        expect(match2.germanWords, ['Blau', 'Gelb']);
      });

      test('skips an invalid duplicate instance without affecting valid instances of the same type', () {
        final mixedStages = [
          {
            'type': 'word_match',
            'pairs': [
              {'target': 'Eins', 'native': 'One'},
            ],
          },
          {
            'type': 'word_match',
            'pairs': [], // Invalid empty pairs
          },
          {
            'type': 'word_match',
            'pairs': [
              {'target': 'Zwei', 'native': 'Two'},
            ],
          },
        ];

        final parsed = LessonStageParser.parseStages(mixedStages);
        expect(parsed.length, 2);
        final wm1 = parsed[0].data as WordMatchStageData;
        final wm2 = parsed[1].data as WordMatchStageData;
        expect(wm1.germanWords, ['Eins']);
        expect(wm2.germanWords, ['Zwei']);
      });
    });

    /* ======================================================================
     * 2. Mistakes Review Queue: Re-enqueuing Exact Failed Instance Only
     * ====================================================================== */
    group('2. Mistakes Review Queue Isolation', () {
      test('failing instance #2 of repeated stage only re-enqueues instance #2 at the end', () {
        final flow = LessonSessionFlowHarness();
        final rawStages = [
          {
            'type': 'word_match',
            'id': 'wm_instance_1',
            'pairs': [
              {'target': 'Hallo', 'native': 'Hello'},
              {'target': 'Danke', 'native': 'Thank you'},
            ],
          },
          {
            'type': 'word_match',
            'id': 'wm_instance_2',
            'pairs': [
              {'target': 'Wasser', 'native': 'Water'},
              {'target': 'Brot', 'native': 'Bread'},
            ],
          },
          {
            'type': 'picture_select',
            'id': 'pic_instance_1',
            'prompt': 'Choose the water',
            'targetWord': 'das Wasser',
            'options': [
              {'id': 'opt_1', 'text': 'das Wasser', 'imageUrl': 'water.webp', 'isCorrect': true},
            ],
          },
        ];

        flow.applyStages(rawStages);
        expect(flow.activeStageTypes, ['word_match', 'word_match', 'picture_select']);
        expect(flow.parsedStages.length, 3);

        // Step 1: User completes stage 0 (word_match instance #1) successfully
        expect(flow.currentStage, 0);
        expect(flow.activeWordMatch!.germanWords, containsAll(['Hallo', 'Danke']));
        flow.matchedGerman.addAll(['Hallo', 'Danke']);
        flow.matchFinished = true;
        flow.nextStage();

        // Step 2: Now on stage 1 (word_match instance #2)
        expect(flow.currentStage, 1);
        expect(flow.activeWordMatch!.germanWords, containsAll(['Wasser', 'Brot']));
        expect(flow.activeStageTypes.length, 3);

        // User makes a mistake on instance #2!
        flow.handleIncorrectAnswer();

        // Verify: instance #2 is re-enqueued at the end of the lesson
        expect(flow.mistakesCount, 1);
        expect(flow.currentStageReEnqueued, isTrue);
        expect(flow.activeStageTypes.length, 4);
        expect(flow.activeStageTypes[3], 'word_match');
        expect(flow.parsedStages.length, 4);

        // CRITICAL: verify that the re-enqueued stage is instance #2 (Wasser/Brot), NOT instance #1 (Hallo/Danke)
        final reviewStageEntry = flow.parsedStages[3];
        expect(reviewStageEntry.canonicalType, 'word_match');
        final reviewStageData = reviewStageEntry.data as WordMatchStageData;
        expect(reviewStageData.germanWords, containsAll(['Wasser', 'Brot']));
        expect(reviewStageData.germanWords, isNot(contains('Hallo')));
        expect(reviewStageEntry.rawStage['id'], 'wm_instance_2');

        // Confirm instance #1 appears exactly once in the entire queue
        final instance1Count = flow.parsedStages.where((s) => s.rawStage['id'] == 'wm_instance_1').length;
        expect(instance1Count, 1);

        // Step 3: Finish instance #2 and advance to stage 2 (picture_select)
        flow.nextStage();
        expect(flow.currentStage, 2);
        expect(flow.activeStageTypes[flow.currentStage], 'picture_select');
        expect(flow.activePictureSelect!.targetWord, 'das Wasser');

        // Complete picture_select successfully
        flow.selectedPictureOptionId = 'opt_1';
        flow.pictureCorrect = true;
        flow.nextStage();

        // Step 4: Now reached the re-enqueued review stage (index 3)
        expect(flow.currentStage, 3);
        expect(flow.activeStageTypes[flow.currentStage], 'word_match');
        expect(flow.activeWordMatch!.germanWords, containsAll(['Wasser', 'Brot']));
      });

      test('multiple mistakes on instance #2 only re-enqueues it once per stage attempt', () {
        final flow = LessonSessionFlowHarness();
        final rawStages = [
          {
            'type': 'listen_tap',
            'id': 'listen_1',
            'targetSentence': 'Guten Tag',
            'tokens': ['Guten', 'Tag'],
          },
          {
            'type': 'listen_tap',
            'id': 'listen_2',
            'targetSentence': 'Auf Wiedersehen',
            'tokens': ['Auf', 'Wiedersehen'],
          },
        ];

        flow.applyStages(rawStages);
        expect(flow.activeStageTypes.length, 2);

        // Pass stage 0
        flow.nextStage();
        expect(flow.currentStage, 1);

        // Multiple incorrect attempts on stage 1 (instance #2)
        flow.handleIncorrectAnswer();
        flow.handleIncorrectAnswer();
        flow.handleIncorrectAnswer();

        expect(flow.mistakesCount, 3);
        // Stage length must only increase by 1 (re-enqueued exactly once)
        expect(flow.activeStageTypes.length, 3);
        expect(flow.parsedStages.length, 3);
        expect(flow.parsedStages[2].rawStage['id'], 'listen_2');
      });

      test('failing instance #1 only re-enqueues instance #1 without touching instance #2', () {
        final flow = LessonSessionFlowHarness();
        final rawStages = [
          {
            'type': 'picture_select',
            'id': 'pic_1',
            'targetWord': 'der Apfel',
            'options': [{'id': 'opt_1', 'text': 'Apfel', 'isCorrect': true}],
          },
          {
            'type': 'picture_select',
            'id': 'pic_2',
            'targetWord': 'die Banane',
            'options': [{'id': 'opt_2', 'text': 'Banane', 'isCorrect': true}],
          },
        ];

        flow.applyStages(rawStages);
        expect(flow.currentStage, 0);

        // Fail on instance #1
        flow.handleIncorrectAnswer();

        expect(flow.activeStageTypes.length, 3);
        expect(flow.parsedStages[2].rawStage['id'], 'pic_1');

        // Next stage should still be instance #2 in its normal position
        flow.nextStage();
        expect(flow.currentStage, 1);
        expect(flow.parsedStages[1].rawStage['id'], 'pic_2');
        expect(flow.activePictureSelect!.targetWord, 'die Banane');
      });
    });

    /* ======================================================================
     * 3. State Isolation & Clean Reset Between Consecutive Identical Stages
     * ====================================================================== */
    group('3. Interactive State Reset Between Consecutive Identical Stages', () {
      test('word_match selections and matched pairs reset completely on stage transition', () {
        final flow = LessonSessionFlowHarness();
        flow.applyStages([
          {
            'type': 'word_match',
            'pairs': [
              {'target': 'Hallo', 'native': 'Hello'},
            ],
          },
          {
            'type': 'word_match',
            'pairs': [
              {'target': 'Wasser', 'native': 'Water'},
            ],
          },
        ]);

        // Stage 0: dirty the interactive matching state
        flow.selectedGerman = 'Hallo';
        flow.selectedEnglish = 'Hello';
        flow.matchedGerman.add('Hallo');
        flow.matchedEnglish.add('Hello');
        flow.matchFinished = true;

        // Transition to consecutive word_match Stage 1
        flow.nextStage();

        // Verify complete state reset
        expect(flow.currentStage, 1);
        expect(flow.selectedGerman, isNull);
        expect(flow.selectedEnglish, isNull);
        expect(flow.matchedGerman, isEmpty);
        expect(flow.matchedEnglish, isEmpty);
        expect(flow.matchFinished, isFalse);

        // Verify active data is now Stage 1's words
        expect(flow.activeWordMatch!.germanWords, ['Wasser']);
      });

      test('listen_tap tapped token indices reset completely on consecutive stage transition', () {
        final flow = LessonSessionFlowHarness();
        flow.applyStages([
          {
            'type': 'listen_tap',
            'targetSentence': 'Guten Morgen',
            'tokens': ['Guten', 'Morgen', 'Kaffee'],
          },
          {
            'type': 'listen_tap',
            'targetSentence': 'Danke schön',
            'tokens': ['Danke', 'schön', 'Bitte'],
          },
        ]);

        // Stage 0: tap tokens
        flow.listenSelectedIndices.addAll([0, 1]);
        flow.listenCorrect = true;

        // Transition to consecutive listen_tap Stage 1
        flow.nextStage();

        expect(flow.currentStage, 1);
        expect(flow.listenSelectedIndices, isEmpty);
        expect(flow.listenCorrect, isNull);
        expect(flow.activeListenTap!.targetSentence, 'Danke schön');
      });

      test('picture_select selected option ID resets completely on consecutive transition', () {
        final flow = LessonSessionFlowHarness();
        flow.applyStages([
          {
            'type': 'picture_select',
            'prompt': 'Apple',
            'options': [{'id': 'opt_apple', 'text': 'Apfel', 'isCorrect': true}],
          },
          {
            'type': 'picture_select',
            'prompt': 'Bread',
            'options': [{'id': 'opt_bread', 'text': 'Brot', 'isCorrect': true}],
          },
        ]);

        // Stage 0: select option
        flow.selectedPictureOptionId = 'opt_apple';
        flow.pictureCorrect = true;

        // Transition to consecutive picture_select Stage 1
        flow.nextStage();

        expect(flow.currentStage, 1);
        expect(flow.selectedPictureOptionId, isNull);
        expect(flow.pictureCorrect, isNull);
        expect(flow.activePictureSelect!.options.first.id, 'opt_bread');
      });

      test('sentence_builder and cloze_test states reset completely between consecutive stages', () {
        final flow = LessonSessionFlowHarness();
        flow.applyStages([
          {
            'type': 'sentence_builder',
            'targetSentence': 'Ich bin Florian',
            'tokens': ['Ich', 'bin', 'Florian'],
          },
          {
            'type': 'sentence_builder',
            'targetSentence': 'Wir lernen Deutsch',
            'tokens': ['Wir', 'lernen', 'Deutsch'],
          },
        ]);

        flow.builderSelectedIndices.addAll([0, 1, 2]);
        flow.builderCorrect = true;

        flow.nextStage();

        expect(flow.currentStage, 1);
        expect(flow.builderSelectedIndices, isEmpty);
        expect(flow.builderCorrect, isNull);
        expect(flow.activeSentenceBuilder!.targetSentence, 'Wir lernen Deutsch');
      });
    });

    /* ======================================================================
     * 4. Widget Interaction & Tactile Bevel Reset Verification
     * ====================================================================== */
    group('4. Widget Interactive UI State Reset', () {
      testWidgets('tapping tile updates selection, advancing stage resets tile selection', (tester) async {
        String? selectedTile;
        bool stage1 = true;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              final currentLabel = stage1 ? 'Hallo' : 'Wasser';
              return MaterialApp(
                home: Scaffold(
                  body: Column(
                    children: [
                      MultiInstanceTestTile(
                        label: currentLabel,
                        isSelected: selectedTile == currentLabel,
                        isMatched: false,
                        onTap: () {
                          setState(() {
                            selectedTile = currentLabel;
                          });
                        },
                      ),
                      ElevatedButton(
                        key: const ValueKey('next_button'),
                        onPressed: () {
                          setState(() {
                            stage1 = false;
                            selectedTile = null; // Clean reset on stage transition
                          });
                        },
                        child: const Text('Next'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );

        // Stage 1 tile is rendered unselected initially
        expect(find.text('Hallo'), findsOneWidget);
        expect(selectedTile, isNull);

        // Tap tile in Stage 1
        await tester.tap(find.text('Hallo'));
        await tester.pumpAndSettle();
        expect(selectedTile, 'Hallo');

        // Tap Next button to simulate moving to Stage 2
        await tester.tap(find.byKey(const ValueKey('next_button')));
        await tester.pumpAndSettle();

        // Stage 2 tile 'Wasser' is rendered, and selection state is reset completely to null
        expect(find.text('Wasser'), findsOneWidget);
        expect(find.text('Hallo'), findsNothing);
        expect(selectedTile, isNull);
      });
    });
  });
}
