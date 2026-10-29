// Strongly-typed representations of parsed interactive lesson stages.

class WordMatchStageData {
  final List<String> germanWords;
  final List<String> englishWords;
  final Map<String, String> solutionPairs;

  const WordMatchStageData({
    required this.germanWords,
    required this.englishWords,
    required this.solutionPairs,
  });
}

class ListenTapStageData {
  final String targetSentence;
  final List<String> targetWords;
  final List<String> wordBank;
  final String audioUrl;

  const ListenTapStageData({
    required this.targetSentence,
    required this.targetWords,
    required this.wordBank,
    required this.audioUrl,
  });
}

class PictureOptionData {
  final String id;
  final String text;
  final String imageUrl;
  final bool isCorrect;

  const PictureOptionData({
    required this.id,
    required this.text,
    required this.imageUrl,
    required this.isCorrect,
  });
}

class PictureSelectStageData {
  final String prompt;
  final String targetWord;
  final String translation;
  final List<PictureOptionData> options;

  const PictureSelectStageData({
    required this.prompt,
    required this.targetWord,
    required this.translation,
    required this.options,
  });
}

/// Robust JSON parser for interactive lesson stages (word_match, listen_tap, etc.)
/// Resilient against server schema variations, high network latency, or partial keys.
class LessonStageParser {
  const LessonStageParser._();

  /// Parses `word_match` or `match_pairs` stage from raw server JSON.
  /// Accepts bilingual key variations: {target, native}, {german, english}, {word, translation}.
  static WordMatchStageData? parseWordMatch(Map<String, dynamic> stage) {
    if (stage['pairs'] is! List) return null;
    final pairsList = stage['pairs'] as List;
    if (pairsList.isEmpty) return null;

    final targetList = <String>[];
    final nativeList = <String>[];
    final solutionPairs = <String, String>{};

    for (final p in pairsList) {
      if (p is Map) {
        final target = (p['target'] ?? p['german'] ?? p['word'] ?? '').toString().trim();
        final native = (p['native'] ?? p['english'] ?? p['translation'] ?? '').toString().trim();
        if (target.isNotEmpty && native.isNotEmpty) {
          targetList.add(target);
          nativeList.add(native);
          solutionPairs[target] = native;
        }
      }
    }

    if (targetList.isEmpty) return null;

    return WordMatchStageData(
      germanWords: targetList,
      englishWords: List<String>.from(nativeList)..shuffle(),
      solutionPairs: solutionPairs,
    );
  }

  /// Parses `listen_tap` stage from raw server JSON.
  /// Extracts sentence tokens, pre-tokenized banks, and remote voice audio URLs.
  static ListenTapStageData? parseListenTap(Map<String, dynamic> stage) {
    final target = stage['targetSentence']?.toString().trim() ?? '';
    final targetWords = target.isNotEmpty
        ? target.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList()
        : <String>[];

    List<String> bank;
    if (stage['tokens'] is List && (stage['tokens'] as List).isNotEmpty) {
      bank = (stage['tokens'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList()
        ..shuffle();
    } else if (targetWords.isNotEmpty) {
      bank = List<String>.from(targetWords)..shuffle();
    } else {
      bank = <String>[];
    }

    if (target.isEmpty && bank.isEmpty) return null;

    final stageAudio = stage['audioUrl']?.toString().trim();
    final audioUrl = (stageAudio != null && stageAudio.isNotEmpty) ? stageAudio : '';

    return ListenTapStageData(
      targetSentence: target,
      targetWords: targetWords,
      wordBank: bank,
      audioUrl: audioUrl,
    );
  }

  /// Parses `picture_select` or `picture_cards` stage from raw server JSON.
  static PictureSelectStageData? parsePictureSelect(Map<String, dynamic> stage) {
    if (stage['options'] is! List) return null;
    final rawOptions = stage['options'] as List;
    if (rawOptions.isEmpty) return null;

    final options = <PictureOptionData>[];
    for (int i = 0; i < rawOptions.length; i++) {
      final opt = rawOptions[i];
      if (opt is Map) {
        options.add(PictureOptionData(
          id: (opt['id'] ?? 'opt_$i').toString(),
          text: (opt['text'] ?? opt['word'] ?? '').toString().trim(),
          imageUrl: (opt['imageUrl'] ?? opt['image'] ?? '').toString().trim(),
          isCorrect: opt['isCorrect'] == true,
        ));
      }
    }

    if (options.isEmpty) return null;

    final prompt = (stage['prompt'] ?? stage['title'] ?? 'Choose the correct picture').toString().trim();
    final targetWord = (stage['targetWord'] ?? stage['target'] ?? '').toString().trim();
    final translation = (stage['translation'] ?? '').toString().trim();

    return PictureSelectStageData(
      prompt: prompt.isNotEmpty ? prompt : 'Choose the correct picture',
      targetWord: targetWord,
      translation: translation,
      options: options,
    );
  }

  /// Detects valid stage types present in the server payload.
  static List<String> extractValidStageTypes(List<dynamic> stages) {
    final types = <String>[];
    for (final raw in stages) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final type = map['type']?.toString();
      if (type == null || type.isEmpty) continue;

      if (type == 'match_pairs' || type == 'word_match') {
        if (parseWordMatch(map) != null) {
          types.add('word_match');
        }
      } else if (type == 'listen_tap') {
        if (parseListenTap(map) != null) {
          types.add('listen_tap');
        }
      } else if (type == 'picture_select' || type == 'picture_cards') {
        if (parsePictureSelect(map) != null) {
          types.add('picture_select');
        }
      } else {
        types.add(type);
      }
    }
    return types;
  }
}
