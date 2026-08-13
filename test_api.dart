import 'package:dio/dio.dart';

void main() async {
  try {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://dolphincoder.com/api',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    
    print('Sending login request...');
    final response = await dio.post(
      '/auth/login',
      data: {
        'email': 'admin@speedupexam.com',
        'password': 'Admin@SpeedUp2024!'
      },
    );
    print('Response status: ${response.statusCode}');
    print('Response data: ${response.data}');
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
