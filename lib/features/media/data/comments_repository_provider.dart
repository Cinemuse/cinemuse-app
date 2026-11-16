import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/data/server_addresses_repository.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/data/imdb_service.dart';
import 'package:cinemuse_app/features/media/data/letterboxd_service.dart';
import 'package:cinemuse_app/features/media/data/series_reviews_service.dart';
import 'package:cinemuse_app/features/media/data/comments_repository_impl.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';

/// Provider for [SeriesReviewsService].
final seriesReviewsServiceProvider = Provider<SeriesReviewsService>((ref) {
  final dio = ref.watch(dioProvider);
  return SeriesReviewsService(
    dio,
    () => ref.read(serverAddressesProvider.future),
  );
});

/// Provider for [LetterboxdService].
final letterboxdServiceProvider = Provider<LetterboxdService>((ref) {
  final dio = ref.watch(dioProvider);
  return LetterboxdService(dio);
});

/// Provider for [ImdbService].
final imdbServiceProvider = Provider<ImdbService>((ref) {
  final dio = ref.watch(dioProvider);
  return ImdbService(dio);
});

/// Provider for the active [CommentsRepository] implementation.
final commentsRepositoryProvider = Provider<CommentsRepository>((ref) {
  final seriesReviewsService = ref.watch(seriesReviewsServiceProvider);
  final letterboxdService = ref.watch(letterboxdServiceProvider);
  final imdbService = ref.watch(imdbServiceProvider);
  final tmdbService = ref.watch(tmdbServiceProvider);

  return CommentsRepositoryImpl(
    seriesReviewsService,
    letterboxdService,
    imdbService,
    tmdbService,
  );
});
