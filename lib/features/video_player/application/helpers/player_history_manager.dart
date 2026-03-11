import 'package:cinemuse_app/core/constants/playback_constants.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerHistoryManager {
  final Ref ref;
  final PlayerParams params;
  final Map<String, dynamic>? mediaDetails;

  PlayerHistoryManager(this.ref, this.params, this.mediaDetails);

  Future<void> saveProgress({
    required int position,
    required int duration,
    required int actualSecondsWatched,
    required int initialPosition,
    required bool isCompletionLogged,
    required Function(bool) onCompletionLogged,
  }) async {
    if (mediaDetails == null || duration < 60) return;

    final user = ref.read(authProvider).value;
    if (user == null) return;

    try {
      final repo = ref.read(watchHistoryRepositoryProvider);
      final mediaType = params.type == 'movie' ? MediaKind.movie : MediaKind.tv;

      final mediaItem = MediaItem(
        tmdbId: int.parse(params.queryId),
        mediaType: mediaType,
        title: mediaDetails!['title'] ?? mediaDetails!['name'] ?? 'Unknown',
        posterPath: mediaDetails!['poster_path'],
        backdropPath: mediaDetails!['backdrop_path'],
        releaseDate: DateTime.tryParse(mediaDetails!['release_date'] ?? mediaDetails!['first_air_date'] ?? ''),
        updatedAt: DateTime.now(),
      );

      await repo.updateProgress(
        userId: user.id,
        media: mediaItem,
        progressSeconds: position,
        totalDuration: duration,
        season: params.season,
        episode: params.episode,
        seriesDetails: params.type == 'tv' ? mediaDetails : null,
        actualSecondsWatched: actualSecondsWatched,
        initialPosition: initialPosition,
      );

      // Handle completion logic using centralized constants
      final isFinished = (duration - position < PlaybackThresholds.completionRemainingSeconds) || 
                         (position / duration > PlaybackThresholds.completionPercentage);
      if (isFinished && !isCompletionLogged) {
        onCompletionLogged(true);
        if (params.type == 'tv') {
          final tmdbIdInt = int.tryParse(params.queryId);
          if (tmdbIdInt != null) {
            ref.invalidate(seriesWatchLogsProvider(tmdbIdInt));
            ref.invalidate(watchedEpisodesMapProvider(tmdbIdInt));
          }
        }
      }
    } catch (e) {
      print("PlayerHistoryManager: Error saving progress: $e");
    }
  }
}
