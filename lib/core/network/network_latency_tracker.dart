import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Immutable record capturing elapsed network latency for a single HTTP request.
class NetworkLatencyRecord {
  final String url;
  final String method;
  final int statusCode;
  final int latencyMs;
  final DateTime timestamp;
  final bool isError;
  final String? errorMessage;

  const NetworkLatencyRecord({
    required this.url,
    required this.method,
    required this.statusCode,
    required this.latencyMs,
    required this.timestamp,
    this.isError = false,
    this.errorMessage,
  });

  @override
  String toString() =>
      'NetworkLatencyRecord($method $url: ${latencyMs}ms, status: $statusCode, error: $isError)';
}

/// Central latency tracker for Hostinger API requests.
/// Tracks real-time elapsed network time, calculates moving averages,
/// and provides event hooks for telemetry or performance diagnostics.
class NetworkLatencyTracker {
  static final NetworkLatencyTracker _instance = NetworkLatencyTracker._internal();
  factory NetworkLatencyTracker() => _instance;
  NetworkLatencyTracker._internal();

  final List<NetworkLatencyRecord> _records = [];
  final List<void Function(NetworkLatencyRecord)> _listeners = [];

  List<NetworkLatencyRecord> get records => List.unmodifiable(_records);

  int get count => _records.length;

  NetworkLatencyRecord? get latestRecord => _records.isNotEmpty ? _records.last : null;

  int? get latestLatencyMs => latestRecord?.latencyMs;

  double get averageLatencyMs {
    if (_records.isEmpty) return 0.0;
    final total = _records.fold<int>(0, (sum, r) => sum + r.latencyMs);
    return total / _records.length;
  }

  void addListener(void Function(NetworkLatencyRecord) listener) {
    _listeners.add(listener);
  }

  void removeListener(void Function(NetworkLatencyRecord) listener) {
    _listeners.remove(listener);
  }

  void recordLatency({
    required String url,
    required String method,
    required int statusCode,
    required int latencyMs,
    bool isError = false,
    String? errorMessage,
  }) {
    final record = NetworkLatencyRecord(
      url: url,
      method: method,
      statusCode: statusCode,
      latencyMs: latencyMs,
      timestamp: DateTime.now(),
      isError: isError,
      errorMessage: errorMessage,
    );
    _records.add(record);
    if (_records.length > 200) {
      _records.removeAt(0);
    }
    for (final listener in List.of(_listeners)) {
      listener(record);
    }
    debugPrint(
      '⏱️ [Hostinger API Latency] $method $url => $statusCode in ${latencyMs}ms'
      '${isError ? " (ERROR: $errorMessage)" : ""}',
    );
  }

  void reset() {
    _records.clear();
    _listeners.clear();
  }
}

/// Dio Interceptor that automatically instruments every request
/// with high-precision start-to-finish network latency measurement.
class NetworkLatencyInterceptor extends Interceptor {
  final NetworkLatencyTracker tracker;

  NetworkLatencyInterceptor({NetworkLatencyTracker? tracker})
      : tracker = tracker ?? NetworkLatencyTracker();

  static const String startTimeKey = '_requestStartTime';
  static const String latencyKey = 'networkLatencyMs';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[startTimeKey] = DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final startTime = response.requestOptions.extra[startTimeKey];
    if (startTime is int) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
      response.extra[latencyKey] = elapsed;
      response.requestOptions.extra[latencyKey] = elapsed;
      tracker.recordLatency(
        url: response.requestOptions.path,
        method: response.requestOptions.method,
        statusCode: response.statusCode ?? 200,
        latencyMs: elapsed,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final startTime = err.requestOptions.extra[startTimeKey];
    if (startTime is int) {
      final elapsed = DateTime.now().millisecondsSinceEpoch - startTime;
      err.requestOptions.extra[latencyKey] = elapsed;
      tracker.recordLatency(
        url: err.requestOptions.path,
        method: err.requestOptions.method,
        statusCode: err.response?.statusCode ?? 0,
        latencyMs: elapsed,
        isError: true,
        errorMessage: err.message,
      );
    }
    handler.next(err);
  }
}
