import 'package:dio/dio.dart';

void main() async {
  try {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://dolphincoder.com/api',
      headers: {'Content-Type': 'application/json'},
    ));
    
    print('Sending login request...');
    final loginRes = await dio.post(
      '/auth/login',
      data: {'email': 'admin@speedupexam.com', 'password': 'Admin@SpeedUp2024!'},
    );
    final token = loginRes.data['token'];
    print('Got token!');
    
    dio.options.headers['Authorization'] = 'Bearer $token';
    
    print('Fetching quizzes...');
    final quizzesRes = await dio.get('/quizzes');
    final quizzes = quizzesRes.data['quizzes'] as List;
    if (quizzes.isEmpty) {
      print('No quizzes found.');
      return;
    }
    final quizId = quizzes.first['_id'];
    print('Using quiz $quizId');
    
    print('Submitting attempt...');
    final attemptRes = await dio.post('/quizzes/$quizId/attempt', data: {
      'answers': [{'questionId': 0, 'selectedIndex': 0}],
      'timeTaken': 10
    });
    
    print('Submit response: ${attemptRes.statusCode}');
    print(attemptRes.data);
    
  } on DioException catch (e) {
    print('Dio Error: ${e.type}');
    print('Message: ${e.message}');
    if (e.response != null) {
      print('Response status: ${e.response?.statusCode}');
      print('Response data: ${e.response?.data}');
    }
  } catch (e) {
    print('Unknown Error: $e');
  }
}
