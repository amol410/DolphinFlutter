class KaraokeStory {
  final String title;
  final String? englishTitle;
  final String? audioUrl;
  final double duration;
  final bool isSprechen;
  final List<KaraokeSentence> sentences;
  final Map<String, dynamic>? vocab;

  const KaraokeStory({
    required this.title,
    this.englishTitle,
    this.audioUrl,
    this.duration = 0.0,
    this.isSprechen = false,
    this.sentences = const [],
    this.vocab,
  });

  factory KaraokeStory.fromJson(Map<String, dynamic> json) {
    var rawSentences = json['sentences'];
    List<KaraokeSentence> parsedSentences = [];
    if (rawSentences is List) {
      parsedSentences = rawSentences
          .map((s) => KaraokeSentence.fromJson(Map<String, dynamic>.from(s)))
          .toList();
    }

    return KaraokeStory(
      title: json['title']?.toString() ?? '',
      englishTitle: json['englishTitle']?.toString(),
      audioUrl: json['audioUrl']?.toString(),
      duration: (json['duration'] is num) ? (json['duration'] as num).toDouble() : 0.0,
      isSprechen: json['isSprechen'] == true,
      sentences: parsedSentences,
      vocab: json['vocab'] is Map ? Map<String, dynamic>.from(json['vocab']) : null,
    );
  }
}

class KaraokeSentence {
  final int index;
  final String text;
  final String translation;
  final double start;
  final double end;
  final List<KaraokeWord> words;

  const KaraokeSentence({
    required this.index,
    required this.text,
    this.translation = '',
    required this.start,
    required this.end,
    this.words = const [],
  });

  factory KaraokeSentence.fromJson(Map<String, dynamic> json) {
    var rawWords = json['words'];
    List<KaraokeWord> parsedWords = [];
    if (rawWords is List) {
      parsedWords = rawWords
          .map((w) => KaraokeWord.fromJson(Map<String, dynamic>.from(w)))
          .toList();
    }

    return KaraokeSentence(
      index: json['index'] is num ? (json['index'] as num).toInt() : 0,
      text: json['text']?.toString() ?? '',
      translation: json['translation']?.toString() ?? '',
      start: (json['start'] is num) ? (json['start'] as num).toDouble() : 0.0,
      end: (json['end'] is num) ? (json['end'] as num).toDouble() : 0.0,
      words: parsedWords,
    );
  }
}

class KaraokeWord {
  final String word;
  final String clean;
  final double start;
  final double end;
  final int sentenceIndex;

  const KaraokeWord({
    required this.word,
    required this.clean,
    required this.start,
    required this.end,
    this.sentenceIndex = 0,
  });

  factory KaraokeWord.fromJson(Map<String, dynamic> json) {
    return KaraokeWord(
      word: json['word']?.toString() ?? '',
      clean: json['clean']?.toString() ?? json['word']?.toString() ?? '',
      start: (json['start'] is num) ? (json['start'] as num).toDouble() : 0.0,
      end: (json['end'] is num) ? (json['end'] as num).toDouble() : 0.0,
      sentenceIndex: json['sentenceIndex'] is num ? (json['sentenceIndex'] as num).toInt() : 0,
    );
  }
}
