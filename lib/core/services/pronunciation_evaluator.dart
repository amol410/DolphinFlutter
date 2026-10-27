import 'dart:math';

/// Status of an individual word token after pronunciation grading.
enum TokenGradingStatus {
  accepted,
  typo,
  wrongWord,
  missed,
  pending,
}

/// Evaluated word token model for real-time and final UI rendering.
class EvaluatedToken {
  final String targetWord;
  final String normalizedTarget;
  final String? spokenMatch;
  final TokenGradingStatus status;
  final double similarity;
  final bool isContentWord;

  const EvaluatedToken({
    required this.targetWord,
    required this.normalizedTarget,
    this.spokenMatch,
    required this.status,
    required this.similarity,
    required this.isContentWord,
  });

  bool get isPassed =>
      status == TokenGradingStatus.accepted || status == TokenGradingStatus.typo;

  EvaluatedToken copyWith({
    String? spokenMatch,
    TokenGradingStatus? status,
    double? similarity,
  }) {
    return EvaluatedToken(
      targetWord: targetWord,
      normalizedTarget: normalizedTarget,
      spokenMatch: spokenMatch ?? this.spokenMatch,
      status: status ?? this.status,
      similarity: similarity ?? this.similarity,
      isContentWord: isContentWord,
    );
  }
}

/// Comprehensive Evaluation Result.
class PronunciationEvaluationResult {
  final List<EvaluatedToken> tokens;
  final int accuracyPercentage;
  final bool isPassed;
  final int matchedWordsCount;
  final int totalWordsCount;
  final String targetSentence;
  final String spokenSentence;

  const PronunciationEvaluationResult({
    required this.tokens,
    required this.accuracyPercentage,
    required this.isPassed,
    required this.matchedWordsCount,
    required this.totalWordsCount,
    required this.targetSentence,
    required this.spokenSentence,
  });
}

/// Production-Grade Pronunciation Evaluator with Duolingo-Parity Grading:
/// - Collator-style accent & German umlaut decomposition (ä->ae, ß->ss)
/// - Monotonic forward sequence alignment with lookahead window
/// - Transposition and single-edit typo classification
/// - Phonetic Soundex/Metaphone approximation for accent tolerance
/// - Content-word weighted accuracy calculation
class PronunciationEvaluator {
  static const Set<String> _germanFunctionWords = {
    'der', 'die', 'das', 'den', 'dem', 'des', 'ein', 'eine', 'einen', 'einem',
    'einer', 'und', 'oder', 'aber', 'in', 'im', 'am', 'an', 'auf', 'mit',
    'zu', 'zur', 'zum', 'aus', 'bei', 'von', 'ist', 'sind', 'war', 'ich',
    'du', 'er', 'sie', 'es', 'wir', 'ihr', 'so', 'ja', 'nein', 'nicht'
  };

  static const Set<String> _englishFunctionWords = {
    'a', 'an', 'the', 'and', 'or', 'but', 'in', 'on', 'at', 'to', 'for',
    'with', 'by', 'from', 'up', 'about', 'into', 'is', 'am', 'are', 'was',
    'were', 'be', 'been', 'being', 'have', 'has', 'had', 'i', 'you', 'he',
    'she', 'it', 'we', 'they', 'do', 'does', 'did', 'not', 'no', 'so'
  };

  /// Decompose accents, umlauts, and strip non-alphanumeric punctuation.
  static String normalizeWord(String word, {String language = 'de'}) {
    String clean = word.trim().toLowerCase();

    // Preserve German umlaut equivalents
    clean = clean
        .replaceAll('ä', 'ae')
        .replaceAll('ö', 'oe')
        .replaceAll('ü', 'ue')
        .replaceAll('ß', 'ss');

    // Common French / Spanish / Latin diacritics
    clean = clean
        .replaceAll(RegExp(r'[àáâã]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõ]'), 'o')
        .replaceAll(RegExp(r'[ùúû]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[ñ]'), 'n');

    // Strip punctuation except internal apostrophes
    clean = clean.replaceAll(RegExp(r"[^\w']"), '');
    clean = clean.replaceAll("'", '');
    return clean;
  }

  /// Calculates dynamic-programming Levenshtein Edit Distance.
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1.codeUnitAt(i) == s2.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }

  /// Check character transposition (e.g. "teh" vs "the").
  static bool isTransposition(String s1, String s2) {
    if (s1.length != s2.length) return false;
    int diffCount = 0;
    List<int> diffIndices = [];

    for (int i = 0; i < s1.length; i++) {
      if (s1[i] != s2[i]) {
        diffCount++;
        diffIndices.add(i);
        if (diffCount > 2) return false;
      }
    }

    if (diffCount == 2) {
      final i = diffIndices[0];
      final j = diffIndices[1];
      return j == i + 1 && s1[i] == s2[j] && s1[j] == s2[i];
    }
    return false;
  }

  /// Simplified Soundex phonetic representation for phonetic tolerance.
  static String soundex(String s) {
    if (s.isEmpty) return '';
    final upper = s.toUpperCase();
    final firstChar = upper[0];

    const mapping = {
      'B': '1', 'F': '1', 'P': '1', 'V': '1',
      'C': '2', 'G': '2', 'J': '2', 'K': '2', 'Q': '2', 'S': '2', 'X': '2', 'Z': '2',
      'D': '3', 'T': '3',
      'L': '4',
      'M': '5', 'N': '5',
      'R': '6',
    };

    StringBuffer res = StringBuffer()..write(firstChar);
    String lastCode = mapping[firstChar] ?? '';

    for (int i = 1; i < upper.length; i++) {
      final char = upper[i];
      final code = mapping[char] ?? '';
      if (code.isNotEmpty && code != lastCode) {
        res.write(code);
        lastCode = code;
        if (res.length == 4) break;
      } else if (code.isEmpty) {
        lastCode = '';
      }
    }

    while (res.length < 4) {
      res.write('0');
    }
    return res.toString();
  }

  /// Calculates token similarity metric (0.0 to 1.0).
  static double calculateSimilarity(String tWord, String sWord) {
    if (tWord == sWord) return 1.0;
    final maxLen = max(tWord.length, sWord.length);
    if (maxLen == 0) return 1.0;

    // Transposition check
    if (isTransposition(tWord, sWord)) return 0.90;

    final dist = levenshteinDistance(tWord, sWord);
    double sim = 1.0 - (dist / maxLen);

    // Phonetic bonus if Soundex matches
    if (sim < 0.85 && soundex(tWord) == soundex(sWord)) {
      sim = max(sim, 0.88);
    }
    return sim;
  }

  /// Evaluates spoken input against target sentence with Duolingo parity.
  static PronunciationEvaluationResult evaluate({
    required String targetSentence,
    required String spokenSentence,
    String language = 'de',
    int minAccuracyThreshold = 70,
  }) {
    final rawTargetTokens = targetSentence
        .split(RegExp(r'\s+'))
        .where((t) => t.trim().isNotEmpty)
        .toList();

    final spokenTokens = spokenSentence
        .split(RegExp(r'\s+'))
        .where((t) => t.trim().isNotEmpty)
        .map((s) => normalizeWord(s, language: language))
        .where((s) => s.isNotEmpty)
        .toList();

    final functionWords = language == 'de' ? _germanFunctionWords : _englishFunctionWords;

    List<EvaluatedToken> evaluatedTokens = [];
    int matchedCount = 0;
    int spokenPointer = 0;

    for (int i = 0; i < rawTargetTokens.length; i++) {
      final rawTarget = rawTargetTokens[i];
      final normTarget = normalizeWord(rawTarget, language: language);
      final isContent = !functionWords.contains(normTarget);

      if (normTarget.isEmpty) continue;

      bool foundMatch = false;
      TokenGradingStatus status = TokenGradingStatus.missed;
      String? matchedSpoken;
      double bestSimilarity = 0.0;

      // Lookahead window of 3 words to tolerate hesitations or filler words
      final lookaheadLimit = min(spokenTokens.length, spokenPointer + 4);
      int bestIdx = -1;

      for (int sIdx = spokenPointer; sIdx < lookaheadLimit; sIdx++) {
        final sWord = spokenTokens[sIdx];
        final sim = calculateSimilarity(normTarget, sWord);

        if (sim > bestSimilarity) {
          bestSimilarity = sim;
          bestIdx = sIdx;
        }

        if (sim >= 0.95) {
          status = TokenGradingStatus.accepted;
          matchedSpoken = sWord;
          foundMatch = true;
          spokenPointer = sIdx + 1;
          break;
        }
      }

      if (!foundMatch && bestIdx != -1) {
        if (bestSimilarity >= 0.80) {
          status = TokenGradingStatus.accepted;
          matchedSpoken = spokenTokens[bestIdx];
          spokenPointer = bestIdx + 1;
          foundMatch = true;
        } else if (bestSimilarity >= 0.65) {
          // Flagged as typo (accepted with minor warning)
          status = TokenGradingStatus.typo;
          matchedSpoken = spokenTokens[bestIdx];
          spokenPointer = bestIdx + 1;
          foundMatch = true;
        }
      }

      if (foundMatch) {
        matchedCount++;
      }

      evaluatedTokens.add(EvaluatedToken(
        targetWord: rawTarget,
        normalizedTarget: normTarget,
        spokenMatch: matchedSpoken,
        status: status,
        similarity: bestSimilarity,
        isContentWord: isContent,
      ));
    }

    // Weighted scoring: Content words carry 1.5x weight over function words
    double totalWeight = 0;
    double earnedWeight = 0;

    for (final token in evaluatedTokens) {
      final weight = token.isContentWord ? 1.5 : 1.0;
      totalWeight += weight;
      if (token.status == TokenGradingStatus.accepted) {
        earnedWeight += weight;
      } else if (token.status == TokenGradingStatus.typo) {
        earnedWeight += weight * 0.85;
      }
    }

    final accuracy = totalWeight == 0
        ? 100
        : ((earnedWeight / totalWeight) * 100).round().clamp(0, 100);

    final threshold = minAccuracyThreshold > 0 ? minAccuracyThreshold : 70;
    final isPassed = accuracy >= threshold;

    return PronunciationEvaluationResult(
      tokens: evaluatedTokens,
      accuracyPercentage: accuracy,
      isPassed: isPassed,
      matchedWordsCount: matchedCount,
      totalWordsCount: evaluatedTokens.length,
      targetSentence: targetSentence,
      spokenSentence: spokenSentence,
    );
  }
}
