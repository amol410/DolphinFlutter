import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import 'models/quiz_model.dart';

class QuizRepository {
  Future<List<QuizModel>> getQuizzes({
    String? q,
    String? subject,
    String? topic,
    int page = 1,
    int limit = 12,
  }) async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.get(ApiConstants.quizzes, queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        'page': page,
        'limit': limit,
      });
      final data = response.data;
      final List list = data is List ? data : (data['quizzes'] ?? data['data'] ?? []);
      return list.map((e) => QuizModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<QuizModel> getQuizById(String id) async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.get('${ApiConstants.quizzes}/$id');
      final data = response.data;
      final quizJson = data is Map && data['quiz'] != null ? data['quiz'] : data;
      return QuizModel.fromJson(quizJson as Map<String, dynamic>);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<AttemptModel> submitAttempt(
    String quizId,
    List<Map<String, dynamic>> answers,
    int timeTaken,
  ) async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.post(
        '${ApiConstants.quizzes}/$quizId/attempt',
        data: {'answers': answers, 'timeTaken': timeTaken},
      );
      return AttemptModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<List<AttemptModel>> getMyAttempts(String quizId) async {
    final dio = await DioClient.getInstance();
    try {
      final response =
          await dio.get('${ApiConstants.quizzes}/$quizId/attempts');
      final data = response.data;
      final List list = data is List ? data : (data['attempts'] ?? []);
      return list
          .map((e) => AttemptModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }
}
