import 'package:flutter_test/flutter_test.dart';
import 'package:dolphincoder/core/services/pronunciation_evaluator.dart';

void main() {
  group('PronunciationEvaluator Tests', () {
    test('100% exact match German sentence', () {
      final res = PronunciationEvaluator.evaluate(
        targetSentence: 'Guten Tag! Wie geht es dir?',
        spokenSentence: 'Guten Tag Wie geht es dir',
        language: 'de',
      );

      expect(res.isPassed, isTrue);
      expect(res.accuracyPercentage, equals(100));
      expect(res.matchedWordsCount, equals(6));
    });

    test('German Umlauts and Eszett normalization', () {
      final res = PronunciationEvaluator.evaluate(
        targetSentence: 'Ich heiße Müller und trinke schönen süßen Tee',
        spokenSentence: 'Ich heisse Mueller und trinke schoenen suessen Tee',
        language: 'de',
      );

      expect(res.isPassed, isTrue);
      expect(res.accuracyPercentage, equals(100));
    });

    test('Tolerates single-character typo and transposition', () {
      final res = PronunciationEvaluator.evaluate(
        targetSentence: 'Zwei Kaffee und ein Wasser bitte',
        spokenSentence: 'Zwei Kafee und ein Wasse bitte',
        language: 'de',
        minAccuracyThreshold: 70,
      );

      expect(res.isPassed, isTrue);
      expect(res.accuracyPercentage, greaterThanOrEqualTo(70));
    });

    test('Fails on completely incorrect sentence', () {
      final res = PronunciationEvaluator.evaluate(
        targetSentence: 'Guten Morgen wie geht es dir',
        spokenSentence: 'Bonjour comment allez vous',
        language: 'de',
        minAccuracyThreshold: 70,
      );

      expect(res.isPassed, isFalse);
      expect(res.accuracyPercentage, lessThan(40));
    });

    test('English language evaluation', () {
      final res = PronunciationEvaluator.evaluate(
        targetSentence: 'Hello, how are you today?',
        spokenSentence: 'Hello how are you today',
        language: 'en',
      );

      expect(res.isPassed, isTrue);
      expect(res.accuracyPercentage, equals(100));
    });
  });
}
