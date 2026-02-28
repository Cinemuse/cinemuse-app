enum AppExceptionType {
  network,
  auth,
  database,
  realtime,
  unknown,
}

class AppException implements Exception {
  final String message;
  final AppExceptionType type;
  final dynamic originalError;

  AppException({
    required this.message,
    required this.type,
    this.originalError,
  });

  @override
  String toString() => 'AppException: $message (Type: ${type.name})';
}
