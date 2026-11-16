import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/constants/playback_constants.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_progress_repository.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/media/application/title_removals.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service_provider.dart';
import 'package:cinemuse_app/features/media/domain/series_domain_service.dart';

class PlayerHistoryManager {
  static const _logTag = 'PlayerHistoryManager';

  final PlayerParams params;
  final MediaItem? mediaItem;

  /// The show's details, to pick the next episode; null for a film.
  final MediaItem? series;

  /// Shows a short message in the player; null clears the last one, so the
  /// same message can show again later.
  final void Function(String? notice) onNotice;

  /// The last progress save failed: the user was already told (DATA-03).
  bool _isSaveFailing = false;

  /// The app's container, which outlives the player's provider: the final
  /// save runs while the player closes, when the player's `ref` can't be
  /// used any more (PLY-01).
  final ProviderContainer _container;

  PlayerHistoryManager({
    required Ref ref,
    required this.params,
    required this.onNotice,
    this.mediaItem,
    this.series,
  }) : _container = ref.container;

  /// Waits for a "Clear progress" or "Stop rewatching" of this title that
  /// waits for its Undo message, so it can't wipe what the player saves now.
  Future<void> _afterRemoval() => _container
      .read(titleRemovalsProvider)
      .after('${mediaItem!.mediaType.name}-${mediaItem!.tmdbId}');

  Future<void> saveProgress({
    required int position,
    required int duration,
    required int actualSecondsWatched,
    required int initialPosition,
    required bool isCompletionLogged,
    required Function(bool) onCompletionLogged,
  }) async {
    if (mediaItem == null || duration < 60) return;
    // The last save is called while the player closes, inside Riverpod's
    // dispose callbacks, where no provider can be read: start after them.
    await Future<void>.value();

    final container = _container;
    final user = container.read(authProvider).value;
    if (user == null) return;

    try {
      final repo = container.read(watchProgressRepositoryProvider);

      await _afterRemoval();
      await repo.updateProgress(
        userId: user.id,
        media: mediaItem!,
        progressSeconds: position,
        totalDuration: duration,
        season: params.season,
        episode: params.episode,
        series: params.type == 'tv' ? series : null,
        actualSecondsWatched: actualSecondsWatched,
        initialPosition: initialPosition,
      );
      if (_isSaveFailing) {
        _isSaveFailing = false;
        onNotice(null);
      }

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
      AppLogger.error(_logTag, 'Progress not saved', error: e, stackTrace: st);
      // Told once, not on every 15 s save while offline (DATA-03).
      if (!_isSaveFailing) {
        _isSaveFailing = true;
        final reason = container.read(errorMapperProvider).map(e).message;
        onNotice(
          container.read(localizationsProvider).playerProgressNotSaved(reason),
        );
      }
    }
  }

  /// Explicitly marks the current episode as completed when the user
  /// presses "Next Episode". Uses a more lenient threshold (50%) since
  /// the user is explicitly signaling they are done with this episode.
  ///
  /// Returns the message to show when the tick failed (DATA-03), else null.
  /// The caller shows it: the player is replaced right after (REV-310).
  Future<String?> markCurrentEpisodeCompleted({
    required int position,
    required int duration,
  }) async {
    if (mediaItem == null || params.type != 'tv') return null;
    if (params.season == null || params.episode == null) return null;
    // Under a minute is never the episode (an add-on's error video), the
    // same rule as [saveProgress].
    if (duration < 60) return null;

    final progressPercentage = position / duration;
    if (progressPercentage < PlaybackThresholds.skipCompletionPercentage) {
      return null;
    }

    final user = _container.read(authProvider).value;
    if (user == null) return null;

    try {
      final repo = _container.read(watchProgressRepositoryProvider);
      await _afterRemoval();
      await repo.completeEpisode(
        userId: user.id,
        tmdbId: int.parse(params.queryId),
        season: params.season!,
        episode: params.episode!,
        durationWatched: position,
        series: series,
      );

      // Invalidate providers so UI updates
      final tmdbIdInt = int.parse(params.queryId);
      _container.invalidate(seriesWatchLogsProvider(tmdbIdInt));
      _container.invalidate(watchedEpisodesMapProvider(tmdbIdInt));

      return null;
    } catch (e, st) {
      AppLogger.error(
        _logTag,
        'Episode not marked as watched',
        error: e,
        stackTrace: st,
      );
      final reason = _container.read(errorMapperProvider).map(e).message;
      return _container
          .read(localizationsProvider)
          .playerEpisodeNotMarkedWatched(reason);
    }
  }

  /// Saves the currently loaded [MediaItem] in the local media cache.
  Future<void> cacheMediaItem() async {
    if (mediaItem == null) return;
    await _container.read(mediaRepositoryProvider).saveMediaItem(mediaItem!);
  }

  /// Calculates the next chronological episode for a series using domain logic
  /// and fetches its TMDB metadata.
  Future<NextEpisodeInfo?> calculateNextEpisode() async {
    if (params.type != 'tv' ||
        params.season == null ||
        params.episode == null ||
        series == null) {
      return null;
    }

    final nextEpResult = _container
        .read(seriesDomainServiceProvider)
        .getNextEpisode(series!, params.season!, params.episode!);

    if (!nextEpResult.isAired) return null;

    NextEpisodeInfo? next = nextEpResult.next;
    if (next != null) {
      final episodes = await _container
          .read(tmdbServiceProvider)
          .getSeasonEpisodes(int.parse(params.queryId), next.season);
      final nextNumber = next.episode;
      final nextEpisode = episodes
          ?.where((e) => e.episodeNumber == nextNumber)
          .firstOrNull;
      if (nextEpisode != null) {
        next = NextEpisodeInfo(
          season: next.season,
          episode: next.episode,
          title: nextEpisode.name,
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
    // Season 0 is the specials: only episode 0 means "no episode" (a show's
    // history row starts at 0/0). Treating season 0 as missing played
    // S0 E37 as S1 E37 (REV-326).
    bool isEpisode(int? season, int? episode) =>
        season != null && season >= 0 && episode != null && episode >= 1;
    final isPicked = isEpisode(params.season, params.episode);
    int resolvedSeason = isPicked ? params.season! : 1;
    int resolvedEpisode = isPicked ? params.episode! : 1;
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
            if (!isPicked && isEpisode(history.season, history.episode)) {
              resolvedSeason = history.season!;
              resolvedEpisode = history.episode!;
            }
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
        AppLogger.warn(
          _logTag,
          'No resume position: history not loaded',
          error: e,
          stackTrace: st,
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
