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

class SentenceBuilderStageData {
  final String prompt;
  final String targetSentence;
  final List<String> targetWords;
  final List<String> wordBank;

  const SentenceBuilderStageData({
    required this.prompt,
    required this.targetSentence,
    required this.targetWords,
    required this.wordBank,
  });
}

class ClozeStageData {
  final String sentence;
  final String translation;
  final String blank;
  final List<String> options;

  const ClozeStageData({
    required this.sentence,
    required this.translation,
    required this.blank,
    required this.options,
  });
}

class TypeWordStageData {
  final String prompt;
  final String translation;
  final String target;
  final String hint;

  const TypeWordStageData({
    required this.prompt,
    required this.translation,
    required this.target,
    required this.hint,
  });
}

class DialogueStageData {
  final String partnerName;
  final String partnerMessage;
  final String translation;
  final List<Map<String, dynamic>> options;

  const DialogueStageData({
    required this.partnerName,
    required this.partnerMessage,
    required this.translation,
    required this.options,
  });
}

class ListenSelectStageData {
  final String sentence;
  final String question;
  final String audioUrl;
  final List<Map<String, dynamic>> options;

  const ListenSelectStageData({
    required this.sentence,
    required this.question,
    required this.audioUrl,
    required this.options,
  });
}

class SprechenStageData {
  final String prompt;
  final String translation;
  final int minAccuracy;
  final String audioUrl;
  final dynamic karaokeData;

  const SprechenStageData({
    required this.prompt,
    required this.translation,
    required this.minAccuracy,
    required this.audioUrl,
    this.karaokeData,
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

  /// Parses `sentence_builder` stage from raw server JSON.
  static SentenceBuilderStageData? parseSentenceBuilder(Map<String, dynamic> stage) {
    final prompt = (stage['prompt'] ?? '').toString().trim();
    final target = (stage['targetSentence'] ?? stage['target'] ?? '').toString().trim();
    final targetWords = target.isNotEmpty
        ? target.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList()
        : <String>[];

    List<String> bank = [];
    if (stage['tokens'] is List && (stage['tokens'] as List).isNotEmpty) {
      bank = (stage['tokens'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList()
        ..shuffle();
    } else if (targetWords.isNotEmpty) {
      bank = List<String>.from(targetWords)..shuffle();
    }

    if (target.isEmpty && bank.isEmpty) return null;

    return SentenceBuilderStageData(
      prompt: prompt,
      targetSentence: target,
      targetWords: targetWords,
      wordBank: bank,
    );
  }

  /// Parses `cloze_test` or `cloze` stage from raw server JSON.
  static ClozeStageData? parseCloze(Map<String, dynamic> stage) {
    final sentence = (stage['sentence'] ?? stage['prompt'] ?? '').toString().trim();
    final trans = (stage['translation'] ?? '').toString().trim();
    final blank = (stage['blank'] ?? stage['target'] ?? stage['correctOption'] ?? stage['correctAnswer'] ?? stage['answer'] ?? '').toString().trim();
    List<String> options = [];
    if (stage['options'] is List && (stage['options'] as List).isNotEmpty) {
      options = (stage['options'] as List)
          .map((o) => (o is Map ? (o['text'] ?? '') : o).toString().trim())
          .where((o) => o.isNotEmpty)
          .toList();
    }
    if (sentence.isEmpty && blank.isEmpty && options.isEmpty) return null;

    return ClozeStageData(
      sentence: sentence,
      translation: trans,
      blank: blank,
      options: options,
    );
  }

  /// Parses `type_word` or `type_input` stage from raw server JSON.
  static TypeWordStageData? parseTypeWord(Map<String, dynamic> stage) {
    final prompt = (stage['prompt'] ?? stage['sentence'] ?? '').toString().trim();
    final trans = (stage['translation'] ?? stage['nativeMeaning'] ?? '').toString().trim();
    final target = (stage['target'] ?? stage['targetWord'] ?? stage['word'] ?? stage['correctAnswer'] ?? '').toString().trim();
    final hint = (stage['hint'] ?? '').toString().trim();

    if (prompt.isEmpty && target.isEmpty) return null;

    return TypeWordStageData(
      prompt: prompt,
      translation: trans,
      target: target,
      hint: hint,
    );
  }

  /// Parses `dialogue_bubble` or `dialogue` stage from raw server JSON.
  static DialogueStageData? parseDialogue(Map<String, dynamic> stage) {
    final name = (stage['partnerName'] ?? stage['speaker'] ?? 'Florian').toString().trim();
    final msg = (stage['partnerMessage'] ?? stage['message'] ?? stage['prompt'] ?? '').toString().trim();
    final trans = (stage['translation'] ?? '').toString().trim();
    final options = <Map<String, dynamic>>[];

    if (stage['options'] is List && (stage['options'] as List).isNotEmpty) {
      final correctOpt = (stage['correctOption'] ?? stage['correctAnswer'] ?? '').toString().trim();
      for (int i = 0; i < (stage['options'] as List).length; i++) {
        final o = (stage['options'] as List)[i];
        if (o is Map) {
          options.add(Map<String, dynamic>.from(o));
        } else {
          final optText = o.toString().trim();
          final isCorrect = correctOpt.isNotEmpty
              ? optText.toLowerCase() == correctOpt.toLowerCase()
              : (i == 0);
          options.add({'text': optText, 'isCorrect': isCorrect});
        }
      }
    }

    if (msg.isEmpty && options.isEmpty) return null;

    return DialogueStageData(
      partnerName: name.isNotEmpty ? name : 'Florian',
      partnerMessage: msg,
      translation: trans,
      options: options,
    );
  }

  /// Parses `listen_select` or `listen_comprehension` stage from raw server JSON.
  static ListenSelectStageData? parseListenSelect(Map<String, dynamic> stage) {
    final sentence = (stage['spokenGerman'] ?? stage['sentence'] ?? stage['targetSentence'] ?? '').toString().trim();
    final question = (stage['question'] ?? stage['prompt'] ?? '').toString().trim();
    final audio = (stage['audioUrl'] ?? '').toString().trim();
    final options = <Map<String, dynamic>>[];

    if (stage['options'] is List && (stage['options'] as List).isNotEmpty) {
      final correctOpt = (stage['correctOption'] ?? stage['correctAnswer'] ?? '').toString().trim();
      for (int i = 0; i < (stage['options'] as List).length; i++) {
        final o = (stage['options'] as List)[i];
        if (o is Map) {
          options.add(Map<String, dynamic>.from(o));
        } else {
          final optText = o.toString().trim();
          final isCorrect = correctOpt.isNotEmpty
              ? optText.toLowerCase() == correctOpt.toLowerCase()
              : (i == 0);
          options.add({'text': optText, 'isCorrect': isCorrect});
        }
      }
    }

    if (sentence.isEmpty && question.isEmpty) return null;

    return ListenSelectStageData(
      sentence: sentence,
      question: question,
      audioUrl: audio,
      options: options,
    );
  }

  /// Parses `sprechen` stage from raw server JSON.
  static SprechenStageData? parseSprechen(Map<String, dynamic> stage) {
    final prompt = (stage['prompt'] ?? '').toString().trim();
    if (prompt.isEmpty) return null;
    final trans = (stage['translation'] ?? '').toString().trim();
    final minAccuracy = stage['minAccuracy'] is num ? (stage['minAccuracy'] as num).toInt() : 75;
    final audio = (stage['audioUrl'] ?? '').toString().trim();

    return SprechenStageData(
      prompt: prompt,
      translation: trans,
      minAccuracy: minAccuracy,
      audioUrl: audio,
      karaokeData: stage['karaokeData'],
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
        if (parseWordMatch(map) != null) types.add('word_match');
      } else if (type == 'listen_tap') {
        if (parseListenTap(map) != null) types.add('listen_tap');
      } else if (type == 'picture_select' || type == 'picture_cards') {
        if (parsePictureSelect(map) != null) types.add('picture_select');
      } else if (type == 'sentence_builder') {
        if (parseSentenceBuilder(map) != null) types.add('sentence_builder');
      } else if (type == 'cloze_test' || type == 'cloze') {
        if (parseCloze(map) != null) types.add('cloze_test');
      } else if (type == 'type_word' || type == 'type_input') {
        if (parseTypeWord(map) != null) types.add('type_word');
      } else if (type == 'dialogue_bubble' || type == 'dialogue') {
        if (parseDialogue(map) != null) types.add('dialogue_bubble');
      } else if (type == 'listen_select' || type == 'listen_comprehension') {
        if (parseListenSelect(map) != null) types.add('listen_select');
      } else if (type == 'sprechen') {
        if (parseSprechen(map) != null) types.add('sprechen');
      } else {
        types.add(type);
      }
    }
    return types;
  }
}
