enum AppExceptionType {
  network,
  auth,
  database,
  streaming,
  realtime,
  validation,
  system,
  unknown,
}

class AppException implements Exception {
  final String message;
  final AppExceptionType type;
  final dynamic originalError;
  final Map<String, dynamic>? metadata;

  AppException({
    required this.message,
    required this.type,
    this.originalError,
    this.metadata,
  });

  @override
  String toString() => 'AppException: $message (Type: ${type.name})';
}
