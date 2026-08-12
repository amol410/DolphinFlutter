import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import 'api_exception.dart';

class DioClient {
  static Dio? _dio;
  static const _storage = FlutterSecureStorage();

  static Future<Dio> getInstance() async {
    if (_dio != null) return _dio!;

    final baseUrl = await ApiConstants.getBaseUrl();

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    // Auth interceptor
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: AppConstants.tokenKey);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _storage.delete(key: AppConstants.tokenKey);
          // Token cleared — router redirect will handle navigation
        }
        handler.next(error);
      },
    ));

    return _dio!;
  }

  static void reset() => _dio = null;

  static ApiException handleError(dynamic e) {
    if (e is DioException) {
      final response = e.response;
      if (response != null) {
        final data = response.data;
        String message = 'Request failed';
        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        }
        return ApiException(message: message, statusCode: response.statusCode);
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return const ApiException(message: 'Connection timed out');
      }
      return const ApiException(message: 'Connection failed. Check your network.');
    }
    return ApiException(message: e.toString());
  }
}
