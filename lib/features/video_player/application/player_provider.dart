import 'dart:async';
import 'dart:developer' as developer;
import 'package:cast/cast.dart';
import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/features/video_player/data/youtube_service.dart';
import 'package:cinemuse_app/core/utils/mime_resolver.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/cast_handler.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/livetv_playback_coordinator.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/youtube_source_handler.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/player_engine_configurator.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/player_history_manager.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/player_initialization_coordinator.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/player_progress_tracker.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/player_source_coordinator.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/stream_fallback_manager.dart';
import 'package:cinemuse_app/features/video_player/application/managers/event_manager.dart';
import 'package:cinemuse_app/features/video_player/application/managers/track_manager.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

final playerControllerProvider = StateNotifierProvider.family
    .autoDispose<PlayerController, AsyncValue<CinemaPlayerState>, PlayerParams>(
      PlayerController.new,
    );

/// High-level presentation controller facade for video playback.
///
/// Coordinates media engine setup, lifecycle, track preferences, and user intents,
/// delegating startup and stream failovers to dedicated coordinators.
class PlayerController extends StateNotifier<AsyncValue<CinemaPlayerState>> {
  final Ref ref;
  final PlayerParams params;
  late PlayerParams resolvedParams;

  Player? _player;
  VideoController? _controller;
  late final YouTubeSourceHandler _youtubeSourceHandler;
  late final UnifiedStreamResolver _resolver;
  late final CastHandler _castHandler;
  final StreamFallbackManager _fallbackManager = StreamFallbackManager();

  PlayerProgressTracker? _progressTracker;
  TrackManager? _trackManager;
  EventManager? _eventManager;
  LiveTvPlaybackCoordinator? _liveTvCoordinator;
  ProviderSubscription? _qualitySubscription;
  PlayerInitializationCoordinator? _initializationCoordinator;
  late final PlayerSourceCoordinator _sourceCoordinator;

  bool _isCompletionLogged = false;

  /// Null until the title's details loaded (and for live TV / YouTube).
  PlayerHistoryManager? get historyManager =>
      _initializationCoordinator?.historyManager;

  PlayerController(this.ref, this.params) : super(const AsyncValue.loading()) {
    resolvedParams = params;
    _resolver = ref.read(unifiedStreamResolverProvider);
    _castHandler = CastHandler(ref);

    _castHandler.onStatusSync = (isPlaying, position, duration) {
      final currentState = state.valueOrNull;
      if (currentState != null) {
        state = AsyncValue.data(
          currentState.copyWith(
            remotePlaying: isPlaying,
            remotePosition: position,
            remoteDuration: duration,
          ),
        );
      }
    };

    _initialize();
  }

  @override
  void dispose() {
    // Can't be awaited here; the position is read before the player goes.
    unawaited(_saveProgress());
    _initializationCoordinator?.skipResolution(); // Ends a search (REV-147).
    _eventManager?.dispose();
    _progressTracker?.dispose();
    _trackManager?.dispose();
    _player?.dispose();
    _qualitySubscription?.close();
    _castHandler.dispose();
    _liveTvCoordinator?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      _setupMediaEngine();

      resolvedParams = await PlayerHistoryManager.resolveInitialParams(
        ref: ref,
        params: params,
      );
      if (!mounted) return; // Closed during the history read (REV-147).

      _initializeManagers();
      _initializeCoordinators();
      _setupProgressTracking();

      if (resolvedParams.type == 'youtube') {
        await _initializationCoordinator!.handleYouTubeInitialization(
          resolvedParams,
        );
        return;
      } else if (resolvedParams.type == 'livetv') {
        await _initializationCoordinator!.handleLiveTvInitialization(params);
        return;
      }

      await _initializationCoordinator!.handleVodInitialization(resolvedParams);
    } catch (e, st) {
      _handleInitializationError(e, st);
    }
  }

  void _setupMediaEngine() {
    if (_player != null) return;
    final bundle = PlayerEngineConfigurator.createEngine();
    _player = bundle.player;
    _controller = bundle.controller;
    _youtubeSourceHandler = YouTubeSourceHandler(
      ref.read(youtubeServiceProvider),
      _player!,
    );
  }

  void _initializeManagers() {
    _trackManager = TrackManager(
      ref: ref,
      player: _player!,
      params: resolvedParams,
      subtitlesKey: params,
    );
    _applyTrackPreferences();

    _eventManager = EventManager(
      ref: ref,
      player: _player!,
      onStateChanged: _triggerStateUpdate,
      onError: (err) => _sourceCoordinator.handlePlayerError(err),
      onCompleted: () => _sourceCoordinator.handlePlaybackCompleted(),
      onFormatDetected: _handleFormatDetected,
    );
    _eventManager!.initialize();

    _liveTvCoordinator = LiveTvPlaybackCoordinator(
      player: _player!,
      controller: _controller!,
      getSettings: () => ref.read(settingsProvider),
      isMounted: () => mounted,
      getCurrentState: () => state.valueOrNull,
      onStateChanged: (newState) {
        if (mounted) {
          state = AsyncValue.data(newState);
        }
      },
      onError: _handleInitializationError,
      unavailableMessage: () =>
          ref.read(localizationsProvider).liveTvStreamUnavailable,
    );

    if (resolvedParams.type == 'livetv') {
      _qualitySubscription = ref.listen(
        settingsProvider.select((s) => s.liveTvQuality),
        (prev, next) {
          final currentChannel = _liveTvCoordinator?.currentChannel;
          if (prev != null && prev != next && currentChannel != null) {
            developer.log(
              'Quality preference changed to $next. Re-resolving channel...',
              name: 'VideoPlayer.PlayerController',
            );
            changeChannel(currentChannel);
          }
        },
      );
    }
  }

  void _initializeCoordinators() {
    _initializationCoordinator = PlayerInitializationCoordinator(
      ref: ref,
      player: _player!,
      controller: _controller!,
      youtubeSourceHandler: _youtubeSourceHandler,
      resolver: _resolver,
      fallbackManager: _fallbackManager,
      getTrackManager: () => _trackManager,
      getLiveTvCoordinator: () => _liveTvCoordinator,
      isMounted: () => mounted,
      getCurrentState: () => state.valueOrNull,
      onStateChanged: (newState) {
        if (mounted) state = AsyncValue.data(newState);
      },
      onError: _handleInitializationError,
      changeChannel: changeChannel,
      applyTrackPreferences: _applyTrackPreferences,
    );

    _sourceCoordinator = PlayerSourceCoordinator(
      ref: ref,
      player: _player!,
      getResolvedParams: () => resolvedParams,
      youtubeSourceHandler: _youtubeSourceHandler,
      resolver: _resolver,
      fallbackManager: _fallbackManager,
      getTrackManager: () => _trackManager,
      getLiveTvCoordinator: () => _liveTvCoordinator,
      isMounted: () => mounted,
      getCurrentState: () => state.valueOrNull,
      onStateChanged: (newState) {
        if (mounted) state = AsyncValue.data(newState);
      },
      // Called only when no source is left to try (REV-164).
      onError: (err, st) {
        final failure = StreamingFailure('No source left: $err', cause: err);
        if (mounted) state = AsyncValue.error(failure, st);
      },
      saveProgress: _saveProgress,
    );
  }

  void _setupProgressTracking() {
    _progressTracker = PlayerProgressTracker(
      player: _player!,
      onProgress: (pos, dur) => _saveProgress(),
    )..start();

    if (mounted) {
      state = AsyncValue.data(
        CinemaPlayerState(
          controller: _controller!,
          availableStreams: const [],
          currentStream: null,
          title: resolvedParams.episodeTitle ?? resolvedParams.queryId,
          isResolving: true,
          activeAudioTrack: _player!.state.track.audio,
          activeSubtitleTrack: _player!.state.track.subtitle,
          isLive: resolvedParams.type == 'livetv',
        ),
      );
    }
  }

  void skipResolution() => _initializationCoordinator?.skipResolution();

  Future<void> changeChannel(Channel channel, {bool isFailover = false}) async {
    if (_player == null) return;
    await _liveTvCoordinator?.changeChannel(channel, isFailover: isFailover);
  }

  Future<void> switchLiveSource(StreamLink link) async {
    if (_player == null) return;
    await _liveTvCoordinator?.switchLiveSource(link);
  }

  Future<void> changeSource(
    StreamCandidate candidate, {
    bool isManual = true,
  }) => _sourceCoordinator.changeSource(candidate, isManual: isManual);

  Future<void> changeFile(int fileId) => _sourceCoordinator.changeFile(fileId);

  void clearError() {
    // valueOrNull: `value` rethrows in the error state (REV-155).
    final current = state.valueOrNull;
    if (current != null) state = AsyncValue.data(current.copyWith(error: null));
  }

  Future<void> pause() async {
    if (state.valueOrNull?.isCasting ?? false) {
      _castHandler.pause();
    } else {
      // Not awaited, as before: callers do not expect player errors here.
      unawaited(_player?.pause());
    }
  }

  Future<void> play() async {
    if (state.valueOrNull?.isCasting ?? false) {
      _castHandler.play();
    } else {
      // Not awaited, as before: callers do not expect player errors here.
      unawaited(_player?.play());
    }
  }

  Future<void> seek(Duration position) async {
    if (state.valueOrNull?.isCasting ?? false) {
      _castHandler.seek(position);
    } else {
      await _player?.seek(position);
    }
  }

  Future<void> startCasting(CastDevice device) async {
    final current = state.valueOrNull;
    final stream = current?.currentStream;
    // Nothing to cast while a source is still resolving (REV-155).
    if (current == null || stream == null) return;
    try {
      state = AsyncValue.data(
        current.copyWith(isCasting: true, selectedCastDevice: device),
      );

      await _castHandler.startCasting(
        device,
        stream,
        current.title,
        _player?.state.position ?? Duration.zero,
        season: resolvedParams.season,
        episode: resolvedParams.episode,
        detectedMimeType: current.detectedMimeType,
      );

      // The cast device plays now; the local pause is best-effort.
      unawaited(_player?.pause());
    } catch (e, st) {
      developer.log(
        'Error starting cast: $e',
        name: 'VideoPlayer.PlayerController',
        error: e,
        stackTrace: st,
        level: 900,
      );
      // Best-effort cleanup after a failed cast start (already logged).
      unawaited(stopCasting());
    }
  }

  Future<void> stopCasting() async {
    await _castHandler.stopCasting();
    final currentState = state.valueOrNull;
    if (currentState != null) {
      state = AsyncValue.data(
        currentState.copyWith(
          isCasting: false,
          selectedCastDevice: null,
          remotePosition: Duration.zero,
          remoteDuration: Duration.zero,
          remotePlaying: false,
        ),
      );
    }
    // Not awaited, as before: callers do not expect player errors here.
    unawaited(_player?.play());
  }

  void updateSubtitleStyle(SubtitleStyle style) {
    if (mounted && state.hasValue) {
      state = AsyncValue.data(
        state.value!.copyWith(customSubtitleStyle: style),
      );
    }
  }

  void updateSubtitleDelay(double delaySeconds) {
    if (_player == null || !mounted) return;
    PlayerEngineConfigurator.setSubtitleDelay(_player!, delaySeconds);
    if (state.hasValue) {
      state = AsyncValue.data(
        state.value!.copyWith(subtitleDelay: delaySeconds),
      );
    }
  }

  void setManualTrackSelection() {
    _trackManager?.setManualSelection();
  }

  Future<void> _saveProgress() async {
    final historyManager = _initializationCoordinator?.historyManager;
    if (_player == null || historyManager == null) return;

    await historyManager.saveProgress(
      position: _player!.state.position.inSeconds,
      duration: _player!.state.duration.inSeconds,
      actualSecondsWatched: _progressTracker?.actualSecondsWatched ?? 0,
      initialPosition: resolvedParams.startPosition ?? 0,
      isCompletionLogged: _isCompletionLogged,
      onCompletionLogged: (val) => _isCompletionLogged = val,
    );
  }

  void _applyTrackPreferences() {
    _trackManager?.applyEnginePreferences(
      isAnime: state.valueOrNull?.isAnime ?? false,
    );
  }

  void _triggerStateUpdate() {
    if (mounted && state.hasValue) {
      state = AsyncValue.data(
        state.value!.copyWith(
          activeAudioTrack: _player?.state.track.audio,
          activeSubtitleTrack: _player?.state.track.subtitle,
        ),
      );
    }
  }

  void _handleFormatDetected(String? format) {
    if (format == null) return;

    final mimeType = MimeResolver.fromEngineFormat(format);
    final current = state.valueOrNull;
    if (mimeType != null && mimeType != current?.detectedMimeType) {
      developer.log(
        'Engine detected format: $format -> $mimeType',
        name: 'VideoPlayer.PlayerController',
      );
      if (mounted && current != null) {
        state = AsyncValue.data(current.copyWith(detectedMimeType: mimeType));
      }
    }
  }

  // Kept raw: the screen tells "every source failed" apart (REV-164).
  void _handleInitializationError(dynamic e, StackTrace st) {
    if (mounted) state = AsyncValue.error(e, st);
  }
}
