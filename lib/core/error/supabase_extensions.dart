import 'dart:async';
import 'package:cinemuse_app/core/error/app_exception.dart';
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

  /// A realtime connection error before the first event becomes [empty], so
  /// a screen waiting for it doesn't spin forever; after it, the error is
  /// dropped and the last value stays (REV-197). Other errors pass through.
  Stream<T> realtimeErrorsAs(T empty) {
    var hasData = false;
    return transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) {
          hasData = true;
          sink.add(data);
        },
        handleError: (error, stackTrace, sink) {
          if (error is! AppException ||
              error.type != AppExceptionType.realtime) {
            sink.addError(error, stackTrace);
          } else if (!hasData) {
            hasData = true;
            sink.add(empty);
          }
        },
      ),
    );
  }
}
