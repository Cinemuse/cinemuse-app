import 'dart:async';
import 'package:cinemuse_app/core/error/supabase_error_handler.dart';

extension SupabaseFutureX<T> on Future<T> {
  Future<T> withErrorHandling() async {
    try {
      return await this;
    } catch (e, s) {
      // Keep the caller's stack trace, or every log points at this helper.
      Error.throwWithStackTrace(SupabaseErrorHandler.handleError(e), s);
    }
  }
}

extension SupabaseStreamX<T> on Stream<T> {
  Stream<T> withErrorHandling() {
    return transform(
      StreamTransformer.fromHandlers(
        handleError: (error, stackTrace, sink) {
          sink.addError(SupabaseErrorHandler.handleError(error), stackTrace);
        },
      ),
    );
  }
}
