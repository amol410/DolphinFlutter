import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import 'models/video_model.dart';

class VideosRepository {
  Future<List<VideoModel>> getVideos({
    String? q,
    int page = 1,
    int limit = 12,
  }) async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.get(ApiConstants.videos, queryParameters: {
        if (q != null && q.isNotEmpty) 'q': q,
        'page': page,
        'limit': limit,
      });
      final data = response.data;
      final List list = data is List ? data : (data['videos'] ?? data['data'] ?? []);
      return list.map((e) => VideoModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }

  Future<VideoModel> getVideoById(String id) async {
    final dio = await DioClient.getInstance();
    try {
      final response = await dio.get('${ApiConstants.videos}/$id');
      final data = response.data;
      final videoJson = data is Map && data['video'] != null ? data['video'] : data;
      return VideoModel.fromJson(videoJson as Map<String, dynamic>);
    } catch (e) {
      throw DioClient.handleError(e);
    }
  }
}
