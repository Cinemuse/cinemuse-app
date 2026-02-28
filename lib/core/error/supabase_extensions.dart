import 'dart:async';
import 'package:cinemuse_app/core/error/supabase_error_handler.dart';

extension SupabaseFutureX<T> on Future<T> {
  Future<T> withErrorHandling() async {
    try {
      return await this;
    } catch (e) {
      throw SupabaseErrorHandler.handleError(e);
    }
  }
}

extension SupabaseStreamX<T> on Stream<T> {
  Stream<T> withErrorHandling() {
    return transform(StreamTransformer.fromHandlers(
      handleError: (error, stackTrace, sink) {
        sink.addError(SupabaseErrorHandler.handleError(error), stackTrace);
      },
    ));
  }
}
