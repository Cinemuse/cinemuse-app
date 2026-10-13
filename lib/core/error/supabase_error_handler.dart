import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/core/error/app_exception.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/error/supabase_failure.dart';

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

    // Offline / timeout: "no connection", not "unknown" (REV-260). Same
    // list of errors as the AppFailure path.
    if (error is Object && supabaseErrorToFailure(error) is NetworkFailure) {
      return AppException(
        message: error.toString(),
        type: AppExceptionType.network,
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
