import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  dio.interceptors.add(RetryInterceptor(dio));

  return dio;
});

class RetryInterceptor extends Interceptor {
  final Dio dio;
  final int maxRetries;
  final List<int> retryStatusCodes;

  RetryInterceptor(this.dio, {this.maxRetries = 3, this.retryStatusCodes = const [502, 503, 504]});

  @override
  Future onError(DioException err, ErrorInterceptorHandler handler) async {
    var requestOptions = err.requestOptions;
    
    // Check if we should retry
    int retryCount = requestOptions.extra['retry_count'] ?? 0;
    
    bool shouldRetry = retryCount < maxRetries && 
        (err.type == DioExceptionType.connectionTimeout ||
         err.type == DioExceptionType.receiveTimeout ||
         (err.response != null && retryStatusCodes.contains(err.response?.statusCode)));

    if (shouldRetry) {
      retryCount++;
      requestOptions.extra['retry_count'] = retryCount;
      
      // Exponential backoff
      final delay = Duration(milliseconds: 500 * (retryCount * retryCount));
      print('NetworkInterceptor: Retrying request (${requestOptions.path}) - Attempt $retryCount after ${delay.inMilliseconds}ms');
      
      await Future.delayed(delay);
      
      try {
        final response = await dio.fetch(requestOptions);
        return handler.resolve(response);
      } on DioException catch (e) {
        return super.onError(e, handler);
      }
    }
    
    return super.onError(err, handler);
  }
}
