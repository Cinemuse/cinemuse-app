import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/error/app_exception.dart';

class SupabaseErrorHandler {
  static AppException handleError(dynamic error) {
    if (error is AuthException) {
      return AppException(
        // English developer text; the UI shows AuthErrorMapper's text.
        message: error.message,
        type: AppExceptionType.auth,
        originalError: error,
      );
    }

    if (error is PostgrestException) {
      return AppException(
        message: error.message,
        type: AppExceptionType.database,
        originalError: error,
      );
    }

    if (error is RealtimeSubscribeException) {
      return AppException(
        message: 'Realtime subscription failed: ${error.toString()}',
        type: AppExceptionType.realtime,
        originalError: error,
      );
    }

    return AppException(
      message: error.toString(),
      type: AppExceptionType.unknown,
      originalError: error,
    );
  }
}
