class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final bool requireVerification;

  const ApiException({
    required this.message,
    this.statusCode,
    this.requireVerification = false,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';
}
