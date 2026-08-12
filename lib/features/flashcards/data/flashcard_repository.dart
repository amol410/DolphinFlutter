import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import 'models/flashcard_model.dart';

class FlashcardRepository {
  Future<List<FlashcardDeck>> getDecks() async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.get(ApiConstants.flashcards);
      final data = response.data;
      final List list = data is List ? data : (data['decks'] ?? data['data'] ?? []);
      return list
          .map((e) => FlashcardDeck.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<FlashcardDeck> getDeckById(String id) async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.get('${ApiConstants.flashcards}/$id');
      final data = response.data;
      final deckJson = data is Map && data['deck'] != null ? data['deck'] : data;
      return FlashcardDeck.fromJson(deckJson as Map<String, dynamic>);
    } catch (e) {
      throw DioClient.handleError(e);
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
}
