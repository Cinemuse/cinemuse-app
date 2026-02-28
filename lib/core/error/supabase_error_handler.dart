import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/error/app_exception.dart';

class SupabaseErrorHandler {
  static AppException handleError(dynamic error) {
    if (error is AuthException) {
      return AppException(
        message: _getAuthMessage(error),
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

  static String _getAuthMessage(AuthException error) {
    final msg = error.message.toLowerCase();
    if (msg.contains('invalid login credentials')) return 'Invalid email or password.';
    if (msg.contains('email not confirmed')) return 'Please confirm your email address.';
    if (msg.contains('user already exists')) return 'An account with this email already exists.';
    return error.message;
  }
}
