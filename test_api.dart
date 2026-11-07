import 'dart:io';
import 'package:dio/dio.dart';

void main() async {
  try {
    final dio = Dio(BaseOptions(
      baseUrl: Platform.environment['API_BASE_URL'] ?? 'https://dolphincoder.com/api',
      headers: {'Content-Type': 'application/json'},
    ));
    
    final email = Platform.environment['ADMIN_EMAIL'] ?? 'admin@speedupexam.com';
    final password = Platform.environment['ADMIN_PASSWORD'] ?? '';
    if (password.isEmpty) {
      print('ADMIN_PASSWORD environment variable not set. Usage: ADMIN_PASSWORD=... dart test_api.dart');
      return;
    }
    
    print('Sending login request...');
    final loginRes = await dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
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
