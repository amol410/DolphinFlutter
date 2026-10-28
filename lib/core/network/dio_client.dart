import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import 'api_exception.dart';
import 'network_latency_tracker.dart';

class DioClient {
  static Dio? _dio;
  static const _storage = FlutterSecureStorage();
  static String? _cachedToken;
  static bool _hasLoadedToken = false;

  static String? get cachedToken => _cachedToken;

  @visibleForTesting
  static void setInstance(Dio dio) {
    _dio = dio;
  }

  static void setToken(String? token) {
    _cachedToken = token;
    _hasLoadedToken = true;
  }

  static Future<void> clearToken() async {
    _cachedToken = null;
    _hasLoadedToken = true;
    try {
      await _storage.delete(key: AppConstants.tokenKey);
    } catch (_) {}
  }

  static Future<Dio> getInstance() async {
    if (_dio != null) return _dio!;

    final baseUrl = await ApiConstants.getBaseUrl();

    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));

    // Network latency tracker interceptor
    _dio!.interceptors.add(NetworkLatencyInterceptor());

    // Auth interceptor (in-memory O(1) token lookup)
    _dio!.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (!_hasLoadedToken) {
          try {
            _cachedToken = await _storage.read(key: AppConstants.tokenKey);
          } catch (_) {}
          _hasLoadedToken = true;
        }
        if (_cachedToken != null) {
          options.headers['Authorization'] = 'Bearer $_cachedToken';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await clearToken();
          // Token cleared — router redirect will handle navigation
        }
        handler.next(error);
      },
    ));

    // HTTP logger — only active in debug/profile builds.
    // In release mode this is skipped to prevent JWT tokens from
    // being logged to the console.
    if (!kReleaseMode) {
      final logger = PrettyDioLogger(
        requestHeader: false,
        requestBody: true,
        responseBody: true,
        error: true,
        compact: true,
      );
      _dio!.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          logger.onRequest(options, handler);
        },
        onResponse: (response, handler) {
          // Skip dumping thousands of lines for heavy path responses to prevent USB logcat freezing
          if (response.requestOptions.path.contains('/gamification/path')) {
            final nodeCount = response.data is Map ? (response.data['nodes'] as List?)?.length ?? 0 : 0;
            debugPrint('⚡ [DIO] ${response.requestOptions.method} ${response.requestOptions.path} => ${response.statusCode} ($nodeCount nodes loaded, body dump suppressed for speed)');
            return handler.next(response);
          }
          logger.onResponse(response, handler);
        },
        onError: (error, handler) {
          logger.onError(error, handler);
        },
      ));
    }

    return _dio!;
  }

  static void reset() {
    _dio = null;
    _cachedToken = null;
    _hasLoadedToken = false;
    NetworkLatencyTracker().reset();
  }

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
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        return const ApiException(message: 'Connection timed out');
      }
      return const ApiException(message: 'Connection failed. Check your network.');
    }
    return ApiException(message: e.toString());
  }
}
