import 'dart:async';
import 'dart:developer' as developer;
import 'package:cast/cast.dart';
import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/subtitles/external_subtitle.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/features/streaming/unified_stream_resolver_provider.dart';
import 'package:cinemuse_app/features/video_player/data/certificate_bundle_source.dart';
import 'package:cinemuse_app/features/video_player/data/youtube_service.dart';
import 'package:cinemuse_app/core/utils/mime_resolver.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
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

final playerControllerProvider = NotifierProvider.autoDispose
    .family<PlayerController, AsyncValue<CinemaPlayerState>, PlayerParams>(
      PlayerController.new,
    );

/// High-level presentation controller facade for video playback.
///
/// Coordinates media engine setup, lifecycle, track preferences, and user intents,
/// delegating startup and stream failovers to dedicated coordinators.
class PlayerController extends Notifier<AsyncValue<CinemaPlayerState>> {
  PlayerController(this.params);

  /// The params the screen opened the player with (the family key).
  final PlayerParams params;

  late PlayerParams resolvedParams;

  Player? _player;
  VideoController? _controller;
  late YouTubeSourceHandler _youtubeSourceHandler;
  late UnifiedStreamResolver _resolver;
  late CastHandler _castHandler;
  late StreamFallbackManager _fallbackManager;

  PlayerProgressTracker? _progressTracker;
  TrackManager? _trackManager;
  EventManager? _eventManager;
  LiveTvPlaybackCoordinator? _liveTvCoordinator;
  PlayerInitializationCoordinator? _initializationCoordinator;
  late PlayerSourceCoordinator _sourceCoordinator;

  bool _isCompletionLogged = false;

  /// This start-up's token, `null` once closed. Retry rebuilds this same
  /// object, so work left from an earlier start-up checks its own token.
  Object? _session;

  bool get _isMounted => _session != null;

  /// Null until the title's details loaded (and for live TV / YouTube).
  PlayerHistoryManager? get historyManager =>
      _initializationCoordinator?.historyManager;

  @override
  AsyncValue<CinemaPlayerState> build() {
    final session = _session = Object();
    resolvedParams = params;
    _isCompletionLogged = false;
    _fallbackManager = StreamFallbackManager();
    _resolver = ref.read(unifiedStreamResolverProvider);
    _castHandler = CastHandler(ref);

    _castHandler.onStatusSync = (isPlaying, position, duration) {
      final currentState = state.value;
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

    ref.onDispose(_close);
    // After build: a state set while building would be overwritten.
    unawaited(Future.microtask(() => _initialize(session)));
    return const AsyncValue.loading();
  }

  void _close() {
    _session = null;
    // Can't be awaited here; the position is read before the player goes.
    unawaited(_saveProgress());
    _initializationCoordinator?.skipResolution(); // Ends a search (REV-147).
    _eventManager?.dispose();
    _progressTracker?.dispose();
    _trackManager?.dispose();
    _player?.dispose();
    _castHandler.dispose();
    _liveTvCoordinator?.dispose();
    // Retry builds again on this object: the next start-up begins empty.
    _player = _controller = _initializationCoordinator = null;
    _eventManager = _progressTracker = _trackManager = null;
    _liveTvCoordinator = null;
  }

  void _emit(Object session, AsyncValue<CinemaPlayerState> value) {
    if (identical(_session, session)) state = value;
  }

  Future<void> _initialize(Object session) async {
    if (!identical(_session, session)) return; // Closed before it started.
    try {
      final certificates = await ref.read(certificateBundleFileProvider.future);
      if (!identical(_session, session)) return; // Closed while it waited.
      final engine = PlayerEngineConfigurator.createEngine(
        certificateBundlePath: certificates.path,
      );
      _player = engine.player;
      _controller = engine.controller;
      _youtubeSourceHandler = YouTubeSourceHandler(
        ref.read(youtubeServiceProvider),
        _player!,
      );
      resolvedParams = await PlayerHistoryManager.resolveInitialParams(
        ref: ref,
        params: params,
      );
      // Closed or retried during the history read (REV-147).
      if (!identical(_session, session)) return;

      _initializeManagers(session);
      _initializeCoordinators(session);
      _setupProgressTracking();
      final start = _initializationCoordinator!;
      await switch (resolvedParams.type) {
        'youtube' => start.handleYouTubeInitialization(resolvedParams),
        'livetv' => start.handleLiveTvInitialization(params),
        _ => start.handleVodInitialization(resolvedParams),
      };
    } catch (e, st) {
      // Kept raw: the screen tells "every source failed" apart (REV-164).
      _emit(session, AsyncValue.error(e, st));
    }
  }

  void _initializeManagers(Object session) {
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
      isMounted: () => identical(_session, session),
      getCurrentState: () => state.value,
      onStateChanged: (newState) => _emit(session, AsyncValue.data(newState)),
      onError: (e, st) => _emit(session, AsyncValue.error(e, st)),
      unavailableMessage: () =>
          ref.read(localizationsProvider).liveTvStreamUnavailable,
      lowerSizeSuggestion: () =>
          ref.read(localizationsProvider).playerPictureSizeSuggestLower,
    );
  }

  void _initializeCoordinators(Object session) {
    _initializationCoordinator = PlayerInitializationCoordinator(
      ref: ref,
      player: _player!,
      controller: _controller!,
      youtubeSourceHandler: _youtubeSourceHandler,
      resolver: _resolver,
      fallbackManager: _fallbackManager,
      getTrackManager: () => _trackManager,
      getLiveTvCoordinator: () => _liveTvCoordinator,
      isMounted: () => identical(_session, session),
      getCurrentState: () => state.value,
      onStateChanged: (newState) => _emit(session, AsyncValue.data(newState)),
      onError: (e, st) => _emit(session, AsyncValue.error(e, st)),
      changeChannel: changeChannel,
      applyTrackPreferences: _applyTrackPreferences,
      // The first source is the app's pick, so it may be skipped.
      onVodSourceStarted: () => unawaited(
        _sourceCoordinator.skipIfSoundLanguageMissing(isManual: false),
      ),
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
      isMounted: () => identical(_session, session),
      getCurrentState: () => state.value,
      onStateChanged: (newState) => _emit(session, AsyncValue.data(newState)),
      // Called only when no source is left to try (REV-164).
      onError: (err, st) {
        final failure = StreamingFailure('No source left: $err', cause: err);
        _emit(session, AsyncValue.error(failure, st));
      },
      saveProgress: _saveProgress,
    );
  }

  void _setupProgressTracking() {
    _progressTracker = PlayerProgressTracker(
      player: _player!,
      onProgress: (pos, dur) => _saveProgress(),
    )..start();

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

  void skipResolution() => _initializationCoordinator?.skipResolution();

  Future<void> changeChannel(Channel channel, {bool isFailover = false}) async {
    if (_player == null) return;
    await _liveTvCoordinator?.changeChannel(channel, isFailover: isFailover);
  }

  Future<void> switchLiveSource(StreamLink link) async {
    if (_player == null) return;
    await _liveTvCoordinator?.switchLiveSource(link);
  }

  /// Plays the live channel at [height] until the channel changes.
  void pickPictureSize(int height) =>
      _liveTvCoordinator?.pickPictureSize(height);

  Future<void> changeSource(
    StreamCandidate candidate, {
    bool isManual = true,
  }) => _sourceCoordinator.changeSource(candidate, isManual: isManual);

  Future<void> changeFile(int fileId) => _sourceCoordinator.changeFile(fileId);

  void clearError() {
    // value: `value` rethrows in the error state (REV-155).
    final current = state.value;
    if (current != null) state = AsyncValue.data(current.copyWith(error: null));
  }

  Future<void> pause() async {
    if (state.value?.isCasting ?? false) {
      _castHandler.pause();
    } else {
      // Not awaited, as before: callers do not expect player errors here.
      unawaited(_player?.pause());
    }
  }

  Future<void> play() async {
    if (state.value?.isCasting ?? false) {
      _castHandler.play();
    } else {
      // Not awaited, as before: callers do not expect player errors here.
      unawaited(_player?.play());
    }
  }

  Future<void> seek(Duration position) async {
    if (state.value?.isCasting ?? false) {
      _castHandler.seek(position);
    } else {
      _liveTvCoordinator?.onSeek();
      _fallbackManager.forgetResumePoint();
      await _player?.seek(position);
    }
  }

  Future<void> startCasting(CastDevice device) async {
    final current = state.value;
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
    final currentState = state.value;
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

  void updateSubtitleDelay(double delaySeconds) {
    if (_player == null || !_isMounted) return;
    PlayerEngineConfigurator.setSubtitleDelay(_player!, delaySeconds);
    if (state.hasValue) {
      state = AsyncValue.data(
        state.value!.copyWith(subtitleDelay: delaySeconds),
      );
    }
  }

  /// Turns on the audio or subtitle [track] the user picked. Throws
  /// [StreamingFailure] if the player refuses it.
  Future<void> selectTrack(Object track) async {
    await _trackManager?.selectTrack(track);
  }

  /// Downloads the external [subtitle] the user picked and turns it on.
  /// Throws [StreamingFailure] if that fails.
  Future<void> applyExternalSubtitle(ExternalSubtitle subtitle) async {
    await _trackManager?.applyExternalSubtitle(subtitle);
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
      isAnime: state.value?.isAnime ?? false,
    );
  }

  void _triggerStateUpdate() {
    if (_isMounted && state.hasValue) {
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
    final current = state.value;
    if (mimeType != null && mimeType != current?.detectedMimeType) {
      developer.log(
        'Engine detected format: $format -> $mimeType',
        name: 'VideoPlayer.PlayerController',
      );
      if (_isMounted && current != null) {
        state = AsyncValue.data(current.copyWith(detectedMimeType: mimeType));
      }
    }
  }
}
