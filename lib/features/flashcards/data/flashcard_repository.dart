import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import 'models/flashcard_model.dart';

class FlashcardRepository {
  static const String _kLocalDecksKey = 'local_difficult_words_decks';

  Future<List<FlashcardDeck>> getLocalDifficultDecks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_kLocalDecksKey);
      if (str == null || str.isEmpty) return [];
      final List decoded = jsonDecode(str) as List;
      return decoded.map((e) => FlashcardDeck.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveLocalDifficultDecks(List<FlashcardDeck> decks) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = decks.map((d) => {
        'id': d.id,
        '_id': d.id,
        'deckName': d.deckName,
        'description': d.description,
        'color': d.color,
        'cardCount': d.cards.length,
        'cards': d.cards.map((c) => {
          'id': c.id,
          '_id': c.id,
          'front': c.front,
          'back': c.back,
          'hint': c.hint,
        }).toList(),
      }).toList();
      await prefs.setString(_kLocalDecksKey, jsonEncode(list));
    } catch (_) {}
  }

  Future<List<FlashcardDeck>> getDecks() async {
    final List<FlashcardDeck> remoteDecks = [];
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.get(ApiConstants.flashcards);
      final data = response.data;
      final List list = data is List ? data : (data['decks'] ?? data['data'] ?? []);
      remoteDecks.addAll(list.map((e) => FlashcardDeck.fromJson(e as Map<String, dynamic>)));
    } catch (_) {
      // Offline or network error
    }

    // Merge local difficult decks that are not already present in remote
    final localDecks = await getLocalDifficultDecks();
    final remoteNames = remoteDecks.map((d) => d.deckName.trim().toLowerCase()).toSet();
    for (final ld in localDecks) {
      if (!remoteNames.contains(ld.deckName.trim().toLowerCase())) {
        remoteDecks.add(ld);
      }
    }
    return remoteDecks;
  }

  Future<FlashcardDeck> getDeckById(String id) async {
    if (id.startsWith('local_')) {
      final locals = await getLocalDifficultDecks();
      final match = locals.firstWhere((d) => d.id == id, orElse: () => throw Exception('Deck not found'));
      return match;
    }

    final dio = await DioClient.getInstance();
    try {
      final response = await dio.get('${ApiConstants.flashcards}/$id');
      final data = response.data;
      final deckJson = data is Map && data['deck'] != null ? data['deck'] : data;
      return FlashcardDeck.fromJson(deckJson as Map<String, dynamic>);
    } catch (e) {
      final locals = await getLocalDifficultDecks();
      final match = locals.firstWhere(
        (d) => d.id == id,
        orElse: () => throw DioClient.handleError(e),
      );
      return match;
    }
  }

  Future<void> saveProgress(
    String deckId,
    Map<String, String> cardResults,
    int masteredCount,
  ) async {
    final dio = await DioClient.getInstance();
    try {
      await dio.post(
        '${ApiConstants.flashcards}/$deckId/progress',
        data: {'cardResults': cardResults, 'masteredCount': masteredCount},
      );
    } catch (e) {
      // Non-critical — don't throw, just log
    }
  }

  Future<FlashcardDeck> createDeck({
    required String deckName,
    required String description,
    required List<Map<String, dynamic>> cards,
    String color = 'purple',
    List<String> tags = const ['difficult-words'],
    bool isPublic = false,
  }) async {
    FlashcardDeck? resultDeck;
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.post(
        ApiConstants.flashcards,
        data: {
          'deckName': deckName,
          'description': description,
          'cards': cards,
          'color': color,
          'tags': tags,
          'isPublic': isPublic,
        },
      );
      final data = response.data;
      final deckJson = data is Map && data['deck'] != null ? data['deck'] : data;
      resultDeck = FlashcardDeck.fromJson(deckJson as Map<String, dynamic>);
    } catch (_) {
      final localId = 'local_${DateTime.now().millisecondsSinceEpoch}';
      resultDeck = FlashcardDeck(
        id: localId,
        deckName: deckName,
        description: description,
        color: color,
        cards: cards.map((c) => Flashcard.fromJson(c)).toList(),
        cardCount: cards.length,
      );
    }

    final locals = await getLocalDifficultDecks();
    locals.removeWhere((d) => d.deckName.trim().toLowerCase() == deckName.trim().toLowerCase());
    locals.add(resultDeck);
    await saveLocalDifficultDecks(locals);

    return resultDeck;
  }

  Future<FlashcardDeck> addCardToDeck(String deckId, Map<String, dynamic> card) async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.post(
        '${ApiConstants.flashcards}/$deckId/cards',
        data: card,
      );
      final data = response.data;
      final deckJson = data is Map && data['deck'] != null ? data['deck'] : data;
      return FlashcardDeck.fromJson(deckJson as Map<String, dynamic>);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<FlashcardDeck> removeCardFromDeck(String deckId, int cardIndex) async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.delete(
        '${ApiConstants.flashcards}/$deckId/cards/$cardIndex',
      );
      final data = response.data;
      final deckJson = data is Map && data['deck'] != null ? data['deck'] : data;
      return FlashcardDeck.fromJson(deckJson as Map<String, dynamic>);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<FlashcardDeck> updateDeckCards(String deckId, List<Map<String, dynamic>> cards) async {
    FlashcardDeck? resultDeck;
    try {
      final dio = await DioClient.getInstance();
      final response = await dio.put(
        '${ApiConstants.flashcards}/$deckId',
        data: {'cards': cards},
      );
      final data = response.data;
      final deckJson = data is Map && data['deck'] != null ? data['deck'] : data;
      resultDeck = FlashcardDeck.fromJson(deckJson as Map<String, dynamic>);
    } catch (_) {
      // Offline fallback
    }

    final locals = await getLocalDifficultDecks();
    final idx = locals.indexWhere((d) => d.id == deckId);
    if (idx != -1) {
      final old = locals[idx];
      final updated = FlashcardDeck(
        id: old.id,
        deckName: old.deckName,
        description: old.description,
        color: old.color,
        cards: cards.map((c) => Flashcard.fromJson(c)).toList(),
        cardCount: cards.length,
      );
      locals[idx] = updated;
      await saveLocalDifficultDecks(locals);
      return updated;
    } else if (resultDeck != null) {
      locals.add(resultDeck);
      await saveLocalDifficultDecks(locals);
      return resultDeck;
    }

    return resultDeck ??
        FlashcardDeck(
          id: deckId,
          deckName: '',
          cards: cards.map((c) => Flashcard.fromJson(c)).toList(),
        );
  }
}
