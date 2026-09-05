import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/network/network_providers.dart';
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

/// Provider for the active [CommentsRepository] implementation.
final commentsRepositoryProvider = Provider<CommentsRepository>((ref) {
  final serializdService = ref.read(serializdServiceProvider);
  final letterboxdService = ref.read(letterboxdServiceProvider);

  return CommentsRepositoryImpl(
    serializdService,
    letterboxdService,
  );
});
