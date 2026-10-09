import 'dart:async';
import 'dart:developer' as developer;
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/core/services/streaming/models/provider_search_status.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/livetv_playback_coordinator.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/vod_source_handler.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/youtube_source_handler.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/player_history_manager.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/stream_fallback_manager.dart';
import 'package:cinemuse_app/features/video_player/application/managers/track_manager.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Coordinates player initialization across VOD, YouTube, and Live TV playback.
class PlayerInitializationCoordinator {
  final Ref ref;
  final Player player;
  final VideoController controller;
  final YouTubeSourceHandler youtubeSourceHandler;
  final UnifiedStreamResolver resolver;
  final StreamFallbackManager fallbackManager;
  final TrackManager? Function() getTrackManager;
  final LiveTvPlaybackCoordinator? Function() getLiveTvCoordinator;
  final bool Function() isMounted;
  final CinemaPlayerState? Function() getCurrentState;
  final void Function(CinemaPlayerState) onStateChanged;
  final void Function(dynamic error, StackTrace st) onError;
  final Future<void> Function(Channel) changeChannel;
  final void Function() applyTrackPreferences;

  MediaItem? _mediaItem;
  Map<String, dynamic>? _rawSeriesDetails;
  PlayerHistoryManager? _historyManager;
  Completer<void>? _skipCompleter;

  PlayerInitializationCoordinator({
    required this.ref,
    required this.player,
    required this.controller,
    required this.youtubeSourceHandler,
    required this.resolver,
    required this.fallbackManager,
    required this.getTrackManager,
    required this.getLiveTvCoordinator,
    required this.isMounted,
    required this.getCurrentState,
    required this.onStateChanged,
    required this.onError,
    required this.changeChannel,
    required this.applyTrackPreferences,
  });

  PlayerHistoryManager? get historyManager => _historyManager;
  MediaItem? get mediaItem => _mediaItem;
  Map<String, dynamic>? get rawSeriesDetails => _rawSeriesDetails;

  void skipResolution() {
    if (_skipCompleter != null && !_skipCompleter!.isCompleted) {
      _skipCompleter!.complete();
    }
  }

  void onProviderStatusUpdate(List<ProviderSearchStatus> statuses) {
    if (!isMounted()) return;
    final currentState = getCurrentState();
    if (currentState != null) {
      onStateChanged(currentState.copyWith(providerStatuses: statuses));
    }
  }

  void onMediaDetailsFetched(
    PlayerParams resolvedParams,
    MediaItem? item,
    Map<String, dynamic>? rawDetails,
  ) {
    _mediaItem = item;
    _rawSeriesDetails = resolvedParams.type == 'tv' ? rawDetails : null;
    _historyManager = PlayerHistoryManager(
      ref: ref,
      params: resolvedParams,
      mediaItem: _mediaItem,
      seriesDetails: _rawSeriesDetails,
    );

    if (isMounted()) {
      final currentState = getCurrentState();
      if (currentState != null) {
        final appLanguage = ref.read(settingsProvider).appLanguage;
        onStateChanged(
          currentState.copyWith(
            title: resolveTitle(resolvedParams, appLanguage),
          ),
        );
      }
    }
  }

  String resolveTitle(PlayerParams resolvedParams, String languageCode) {
    return _mediaItem?.getLocalizedTitle(languageCode) ??
        resolvedParams.episodeTitle ??
        resolvedParams.queryId;
  }

  Future<void> handleYouTubeInitialization(PlayerParams resolvedParams) async {
    final result = await youtubeSourceHandler.initialize(resolvedParams);
    if (isMounted()) {
      onStateChanged(
        CinemaPlayerState(
          controller: controller,
          availableStreams: result.candidates,
          currentStream: result.resolvedStream,
          title: result.title,
          activeAudioTrack: player.state.track.audio,
          activeSubtitleTrack: player.state.track.subtitle,
          isLive: resolvedParams.type == 'livetv',
        ),
      );
    }
  }

  Future<void> handleLiveTvInitialization(PlayerParams params) async {
    getLiveTvCoordinator()?.initializeIdleState(
      defaultTitle: params.episodeTitle ?? 'Live TV',
    );
    final initialChannel = ref.read(selectedChannelProvider);
    if (initialChannel != null) {
      ref.read(recentChannelIdsProvider.notifier).push(initialChannel.uniqueId);
      await changeChannel(initialChannel);
    }
  }

  Future<void> handleVodInitialization(PlayerParams resolvedParams) async {
    _skipCompleter = Completer<void>();
    final handler = VodSourceHandler(
      resolver,
      ref.read(tmdbServiceProvider),
      player,
    );
    final vodResult = await handler.initialize(
      resolvedParams,
      onStatusUpdate: onProviderStatusUpdate,
      onMediaDetailsFetched: (item, rawDetails) =>
          onMediaDetailsFetched(resolvedParams, item, rawDetails),
      skipTrigger: _skipCompleter!.future,
    );

    await performPostInitialization(resolvedParams, vodResult);
  }

  Future<void> performPostInitialization(
    PlayerParams resolvedParams,
    VodInitializationResult vodResult,
  ) async {
    if (vodResult.mediaItem != null) {
      _mediaItem = vodResult.mediaItem;
      _rawSeriesDetails = resolvedParams.type == 'tv'
          ? vodResult.mediaDetails
          : null;
    }

    if (isMounted()) {
      onStateChanged(
        CinemaPlayerState(
          controller: controller,
          availableStreams: vodResult.candidates,
          currentStream: vodResult.resolvedStream,
          title: resolveTitle(
            resolvedParams,
            ref.read(settingsProvider).appLanguage,
          ),
          nextEpisode: null,
          providerStatuses: getCurrentState()?.providerStatuses ?? const [],
          isAnime: vodResult.isAnime,
          activeAudioTrack: player.state.track.audio,
          activeSubtitleTrack: player.state.track.subtitle,
          isLive: resolvedParams.type == 'livetv',
        ),
      );
    }

    // Reset retry count on successful initialization
    fallbackManager.resetRetryCount();

    // Apply track preferences after state is updated with isAnime
    applyTrackPreferences();
    unawaited(
      getTrackManager()?.ensurePreferredTrack(isAnime: vodResult.isAnime) ??
          Future.value(),
    );

    unawaited(ensureMediaCached());
    handleInitialSeek(resolvedParams);
    loadNextEpisodeAsync();
  }

  Future<void> loadNextEpisodeAsync() async {
    try {
      final nextEpisode = await _historyManager?.calculateNextEpisode();
      if (isMounted() && nextEpisode != null) {
        final current = getCurrentState();
        if (current != null) {
          onStateChanged(current.copyWith(nextEpisode: nextEpisode));
        }
      }
    } catch (e, s) {
      developer.log(
        'Failed to calculate or load next episode asynchronously',
        name: 'PlayerInitializationCoordinator',
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> ensureMediaCached() async {
    await _historyManager?.cacheMediaItem();
  }

  void handleInitialSeek(PlayerParams resolvedParams) {
    final startPos = resolvedParams.startPosition;
    if (startPos != null && startPos > 0) {
      player.stream.duration
          .firstWhere((d) => d.inSeconds > 0)
          .timeout(const Duration(seconds: 4), onTimeout: () => Duration.zero)
          .then((_) {
            player.seek(Duration(seconds: startPos));
          })
          .catchError((_) {
            player.seek(Duration(seconds: startPos));
          });
    }
  }
}
