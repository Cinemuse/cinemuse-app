import 'package:cinemuse_app/core/network/retry_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A plain desktop Chrome User-Agent. Some stream sites refuse requests that
/// don't look like a browser; APIs (TMDB, debrid) accept it too (STR-10).
const browserUserAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      // Short connect timeout: with retries, a dead host still fails in ~30 s
      // instead of ~2 min (STR-11).
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'User-Agent': browserUserAgent},
    ),
  );

  dio.interceptors.add(RetryInterceptor(dio));

  return dio;
});
