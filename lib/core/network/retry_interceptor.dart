import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:dio/dio.dart';

/// Retries a failed request after a timeout or a 502/503/504, with growing
/// pauses between tries.
///
/// Only GET and HEAD are retried: re-sending a POST could repeat its effect
/// (e.g. add the same torrent to Real-Debrid twice, STR-11).
class RetryInterceptor extends Interceptor {
  static const defaultMaxRetries = 2;
  static const _retryableMethods = {'GET', 'HEAD'};
  static const _retryCountKey = 'retry_count';

  final Dio dio;
  final int maxRetries;
  final List<int> retryStatusCodes;

  /// Pause before retry n is [baseDelay] × n². Tests pass [Duration.zero].
  final Duration baseDelay;

  RetryInterceptor(
    this.dio, {
    this.maxRetries = defaultMaxRetries,
    this.retryStatusCodes = const [502, 503, 504],
    this.baseDelay = const Duration(milliseconds: 500),
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestOptions = err.requestOptions;
    final int retryCount = requestOptions.extra[_retryCountKey] ?? 0;

    if (retryCount >= maxRetries || !_isRetryable(err)) {
      return super.onError(err, handler);
    }

    final attempt = retryCount + 1;
    requestOptions.extra[_retryCountKey] = attempt;
    final delay = baseDelay * (attempt * attempt);
    AppLogger.debug(
      'RetryInterceptor',
      'Retrying ${requestOptions.method} ${requestOptions.uri.host} '
          '(attempt $attempt after ${delay.inMilliseconds} ms)',
    );
    await Future<void>.delayed(delay);

    try {
      final response = await dio.fetch<dynamic>(requestOptions);
      return handler.resolve(response);
    } on DioException catch (e) {
      return super.onError(e, handler);
    }
  }

  bool _isRetryable(DioException err) {
    final method = err.requestOptions.method.toUpperCase();
    if (!_retryableMethods.contains(method)) return false;
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        retryStatusCodes.contains(err.response?.statusCode);
  }
}
