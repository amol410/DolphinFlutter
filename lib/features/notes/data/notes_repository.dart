import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import 'models/note_model.dart';

class NotesRepository {
  Future<List<NoteModel>> getNotes({
    String? q,
    String? subject,
    String? topic,
    int page = 1,
    int limit = 12,
  }) async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.get(ApiConstants.notes, queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        if (subject != null && subject.isNotEmpty) 'subject': subject,
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        'page': page,
        'limit': limit,
      });
      final data = response.data;
      final List list = data is List ? data : (data['notes'] ?? data['data'] ?? []);
      return list.map((e) => NoteModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<NoteModel> getNoteById(String id) async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.get('${ApiConstants.notes}/$id');
      final data = response.data;
      final noteJson = data is Map && data['note'] != null ? data['note'] : data;
      return NoteModel.fromJson(noteJson as Map<String, dynamic>);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }
}
