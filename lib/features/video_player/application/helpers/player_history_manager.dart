import 'package:cinemuse_app/core/constants/playback_constants.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlayerHistoryManager {
  final Ref ref;
  final PlayerParams params;
  final MediaItem? mediaItem;
  final Map<String, dynamic>? seriesDetails;

  PlayerHistoryManager({
    required this.ref,
    required this.params,
    this.mediaItem,
    this.seriesDetails,
  });

  Future<void> saveProgress({
    required int position,
    required int duration,
    required int actualSecondsWatched,
    required int initialPosition,
    required bool isCompletionLogged,
    required Function(bool) onCompletionLogged,
  }) async {
    if (mediaItem == null || duration < 60) return;

    final user = ref.read(authProvider).value;
    if (user == null) return;
    // The final save runs while the player closes: refresh through the
    // app's container, which outlives the player's provider (PLY-01).
    final container = ref.container;

    try {
      final repo = ref.read(watchHistoryRepositoryProvider);

      await repo.updateProgress(
        userId: user.id,
        media: mediaItem!,
        progressSeconds: position,
        totalDuration: duration,
        season: params.season,
        episode: params.episode,
        seriesDetails: params.type == 'tv' ? seriesDetails : null,
        actualSecondsWatched: actualSecondsWatched,
        initialPosition: initialPosition,
      );

      // Handle completion logic using centralized constants
      final isFinished =
          (duration - position <
              PlaybackThresholds.completionRemainingSeconds) ||
          (position / duration > PlaybackThresholds.completionPercentage);
      if (isFinished && !isCompletionLogged) {
        onCompletionLogged(true);
        if (params.type == 'tv') {
          final tmdbIdInt = int.tryParse(params.queryId);
          if (tmdbIdInt != null) {
            container.invalidate(seriesWatchLogsProvider(tmdbIdInt));
            container.invalidate(watchedEpisodesMapProvider(tmdbIdInt));
          }
        }
      }
    } catch (e, st) {
      developer.log(
        'Error saving progress',
        name: 'VideoPlayer.PlayerHistoryManager',
        error: e,
        stackTrace: st,
        level: 900,
      );
    }
  }

  /// Explicitly marks the current episode as completed when the user
  /// presses "Next Episode". Uses a more lenient threshold (50%) since
  /// the user is explicitly signaling they are done with this episode.
  Future<bool> markCurrentEpisodeCompleted({
    required int position,
    required int duration,
  }) async {
    if (mediaItem == null || params.type != 'tv') return false;
    if (params.season == null || params.episode == null) return false;
    if (duration <= 0) return false;

    final progressPercentage = position / duration;
    if (progressPercentage < PlaybackThresholds.skipCompletionPercentage) {
      return false;
    }

    final user = ref.read(authProvider).value;
    if (user == null) return false;

    try {
      final repo = ref.read(watchHistoryRepositoryProvider);
      await repo.completeEpisode(
        userId: user.id,
        tmdbId: int.parse(params.queryId),
        season: params.season!,
        episode: params.episode!,
        durationWatched: position,
        seriesDetails: seriesDetails,
      );

      // Invalidate providers so UI updates
      final tmdbIdInt = int.parse(params.queryId);
      ref.invalidate(seriesWatchLogsProvider(tmdbIdInt));
      ref.invalidate(watchedEpisodesMapProvider(tmdbIdInt));

      return true;
    } catch (e, st) {
      developer.log(
        'Error marking episode completed',
        name: 'VideoPlayer.PlayerHistoryManager',
        error: e,
        stackTrace: st,
        level: 900,
      );
      return false;
    }
  }

  /// Persists the currently loaded [MediaItem] to the watch history repository cache.
  Future<void> cacheMediaItem() async {
    if (mediaItem == null) return;
    final repo = ref.read(watchHistoryRepositoryProvider);
    await repo.saveMediaItem(mediaItem!);
  }

  /// Calculates the next chronological episode for a series using domain logic
  /// and fetches its TMDB metadata.
  Future<NextEpisodeInfo?> calculateNextEpisode() async {
    if (params.type != 'tv' ||
        params.season == null ||
        params.episode == null ||
        seriesDetails == null) {
      return null;
    }

    final nextEpResult = ref
        .read(seriesDomainServiceProvider)
        .getNextEpisode(seriesDetails!, params.season!, params.episode!);

    if (!nextEpResult.isAired) return null;

    NextEpisodeInfo? next = nextEpResult.next;
    if (next != null) {
      final seasonDetails = await ref
          .read(tmdbServiceProvider)
          .getSeasonDetails(int.parse(params.queryId), next.season);
      final episodes = seasonDetails?['episodes'] as List? ?? [];
      final nextEpData = episodes.firstWhere(
        (e) => e['episode_number'] == next?.episode,
        orElse: () => null,
      );
      if (nextEpData != null) {
        next = NextEpisodeInfo(
          season: next.season,
          episode: next.episode,
          title: nextEpData['name'],
        );
      }
    }
    return next;
  }

  /// Resolves the initial season, episode, and resume position by checking
  /// previous watch history for the user.
  static Future<PlayerParams> resolveInitialParams({
    required Ref ref,
    required PlayerParams params,
  }) async {
    int resolvedSeason = (params.season == null || params.season! < 1)
        ? 1
        : params.season!;
    int resolvedEpisode = (params.episode == null || params.episode! < 1)
        ? 1
        : params.episode!;
    int resolvedStartPosition = params.startPosition ?? 0;

    final user = ref.read(authProvider).value;
    if (user != null && (params.type == 'movie' || params.type == 'tv')) {
      try {
        final repo = ref.read(watchHistoryRepositoryProvider);
        final history = await repo.getHistoryItem(
          user.id,
          params.queryId,
          params.type,
        );
        if (history != null) {
          if (params.type == 'tv') {
            final hSeason = (history.season == null || history.season! < 1)
                ? null
                : history.season;
            final hEpisode = (history.episode == null || history.episode! < 1)
                ? null
                : history.episode;
            resolvedSeason = (params.season == null || params.season! < 1)
                ? (hSeason ?? 1)
                : params.season!;
            resolvedEpisode = (params.episode == null || params.episode! < 1)
                ? (hEpisode ?? 1)
                : params.episode!;
            if (params.startPosition == null &&
                resolvedSeason == history.season &&
                resolvedEpisode == history.episode) {
              resolvedStartPosition = history.progressSeconds;
            }
          } else if (params.type == 'movie') {
            if (params.startPosition == null) {
              resolvedStartPosition = history.progressSeconds;
            }
          }
        }
      } catch (e, st) {
        developer.log(
          'Failed to fetch watch history for initial playback position',
          name: 'VideoPlayer.PlayerHistoryManager',
          error: e,
          stackTrace: st,
          level: 700,
        );
      }
    }

    return params.copyWith(
      season: params.type == 'movie' ? null : resolvedSeason,
      episode: params.type == 'movie' ? null : resolvedEpisode,
      startPosition: resolvedStartPosition,
    );
  }
}
