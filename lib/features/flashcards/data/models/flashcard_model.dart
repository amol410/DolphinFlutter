class FlashcardDeck {
  final String id;
  final String deckName;
  final String? description;
  final String? color;
  final List<Flashcard> cards;
  final int cardCount;
  final bool isPublic;

  const FlashcardDeck({
    required this.id,
    required this.deckName,
    this.description,
    this.color,
    this.cards = const [],
    this.cardCount = 0,
    this.isPublic = true,
  });

  factory FlashcardDeck.fromJson(Map<String, dynamic> json) {
    return FlashcardDeck(
      id: json['_id']?.toString() ?? '',
      deckName: json['deckName'] ?? '',
      description: json['description'],
      color: json['color'],
      cards: (json['cards'] as List? ?? [])
          .map((c) => Flashcard.fromJson(c as Map<String, dynamic>))
          .toList(),
      cardCount: json['cardCount'] ?? (json['cards'] as List? ?? []).length,
      isPublic: json['isPublic'] ?? true,
    );
  }
}

class Flashcard {
  final String id;
  final String front;
  final String back;
  final String? hint;

  const Flashcard({
    required this.id,
    required this.front,
    required this.back,
    this.hint,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      id: json['_id']?.toString() ?? '',
      front: json['front'] ?? '',
      back: json['back'] ?? '',
      hint: json['hint'],
    );
  }
}
