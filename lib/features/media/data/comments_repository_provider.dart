import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/features/media/data/imdb_service.dart';
import 'package:cinemuse_app/features/media/data/letterboxd_service.dart';
import 'package:cinemuse_app/features/media/data/serializd_service.dart';
import 'package:cinemuse_app/features/media/data/comments_repository_impl.dart';
import 'package:cinemuse_app/features/media/domain/comments_repository.dart';

/// Provider for [SerializdService].
final serializdServiceProvider = Provider<SerializdService>((ref) {
  final dio = ref.read(dioProvider);
  return SerializdService(dio);
});

/// Provider for [LetterboxdService].
final letterboxdServiceProvider = Provider<LetterboxdService>((ref) {
  final dio = ref.read(dioProvider);
  return LetterboxdService(dio);
});

/// Provider for [ImdbService].
final imdbServiceProvider = Provider<ImdbService>((ref) {
  final dio = ref.read(dioProvider);
  return ImdbService(dio);
});

/// Provider for the active [CommentsRepository] implementation.
final commentsRepositoryProvider = Provider<CommentsRepository>((ref) {
  final serializdService = ref.read(serializdServiceProvider);
  final letterboxdService = ref.read(letterboxdServiceProvider);
  final imdbService = ref.read(imdbServiceProvider);
  final tmdbService = ref.read(tmdbServiceProvider);

  return CommentsRepositoryImpl(
    serializdService,
    letterboxdService,
    imdbService,
    tmdbService,
  );
});
