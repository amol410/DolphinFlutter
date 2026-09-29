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
    final rawCards = json['cards'];
    List<Flashcard> parsedCards = [];
    if (rawCards is List) {
      parsedCards = rawCards
          .map((c) => Flashcard.fromJson(c is Map<String, dynamic> ? c : Map<String, dynamic>.from(c as Map)))
          .toList();
    }
    return FlashcardDeck(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      deckName: json['deckName'] ?? '',
      description: json['description']?.toString(),
      color: json['color']?.toString(),
      cards: parsedCards,
      cardCount: json['cardCount'] is int ? json['cardCount'] as int : parsedCards.length,
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
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      front: json['front']?.toString() ?? '',
      back: json['back']?.toString() ?? '',
      hint: json['hint']?.toString(),
    );
  }
}
