import 'dart:async';
import 'dart:io' as io;
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/core/services/video/youtube_service.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:cinemuse_app/core/services/streaming/models/provider_search_status.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/vod_source_handler.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/livetv_source_handler.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:flutter/foundation.dart';


import 'package:cast/cast.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/application/managers/playback_manager.dart';
import 'package:cinemuse_app/features/video_player/application/managers/event_manager.dart';
import 'package:cinemuse_app/features/video_player/application/managers/track_manager.dart';
import 'package:cinemuse_app/features/video_player/application/managers/initialization_manager.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/youtube_handler.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/rd_handler.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/cast_handler.dart';
import 'package:cinemuse_app/core/application/l10n_provider.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/player_history_manager.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/player_progress_tracker.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/core/utils/mime_resolver.dart';

// Convert back to StateNotifierProvider for compatibility/simplicity
final playerControllerProvider = StateNotifierProvider.family.autoDispose<PlayerController, AsyncValue<CinemaPlayerState>, PlayerParams>(
  (ref, params) => PlayerController(ref, params),
);

class PlayerController extends StateNotifier<AsyncValue<CinemaPlayerState>> {
  final Ref ref;
  final PlayerParams params;
  
  Player? _player;
  VideoController? _controller;
  late final YoutubeHandler _youtubeHandler;
  late final RdHandler _rdHandler;
  late final CastHandler _castHandler;
  
  Map<String, dynamic>? _mediaDetails;
  bool _isCompletionLogged = false;
  PlayerHistoryManager? _historyManager;
  PlayerProgressTracker? _progressTracker;
  TrackManager? _trackManager;
  EventManager? _eventManager;
  PlaybackManager? _playbackManager;
  InitializationManager? _initializationManager;
  LiveTvSourceHandler? _liveTvHandler;
  
  // --- Live TV Failover State ---
  bool _isChangingChannel = false;
  int _activeRequestId = 0;
  Channel? _currentChannel;
  StreamLink? _currentLink;

  PlayerController(this.ref, this.params) : super(const AsyncValue.loading()) {
    
    // Initialize Handlers
    _youtubeHandler = YoutubeHandler(ref.read(youtubeServiceProvider));
    _rdHandler = RdHandler(ref.read(unifiedStreamResolverProvider));
    _castHandler = CastHandler(ref, ref.read(unifiedStreamResolverProvider));
    
    _castHandler.onStatusSync = (isPlaying, position, duration) {
       final currentState = state.valueOrNull;
       if (currentState != null) {
         state = AsyncValue.data(currentState.copyWith(
           remotePlaying: isPlaying,
           remotePosition: position,
           remoteDuration: duration,
         ));
       }
    };

    _initialize();
  }

  @override
  void dispose() {
    _saveProgress(force: true);
    _eventManager?.dispose();
    _progressTracker?.dispose();
    _trackManager?.dispose();
    _player?.dispose();
    _youtubeHandler.dispose();
    _rdHandler.dispose();
    _castHandler.dispose();
    _liveTvHandler?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      _setupMediaEngine();
      _initializeManagers();
      _setupProgressTracking();

      if (params.type == 'youtube') {
        await _handleYouTubeInitialization();
        return;
      } else if (params.type == 'livetv') {
        await _handleLiveTvInitialization();
        return;
      }

      await _handleVodInitialization();
    } catch (e, st) {
      _handleInitializationError(e, st);
    }
  }

  void _setupMediaEngine() {
    if (_player != null) return;
    
    _player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.warn,
      ),
    );

    _controller = VideoController(
      _player!,
      configuration: VideoControllerConfiguration(
        hwdec: io.Platform.isAndroid ? 'mediacodec' : 'auto-safe',
        vo: io.Platform.isAndroid ? 'gpu' : null,
        enableHardwareAcceleration: true,
      ),
    );

    try {
      final mpv = _player!.platform as dynamic;
      // ── Hardware Decoding & Rendering ─────────────────────────────────────
      // vd-lavc-dr: Zero-copy direct rendering from decoder to GPU texture.
      // Reduces RAM usage and improves throughput, especially on 4K/HEVC.
      mpv.setProperty('vd-lavc-dr', 'yes');
      mpv.setProperty('vd-lavc-threads', '0'); // Auto-pick optimal thread count

      // ── Video Sync & Smoothness ───────────────────────────────────────────
      // display-resample: syncs to the monitor's refresh rate, eliminates judder.
      mpv.setProperty('video-sync', 'display-resample');
      
      // Interpolation to smooth out frame pacing (reduces judder on 24fps content).
      mpv.setProperty('interpolation', 'yes');
      mpv.setProperty('tscale', 'oversample'); 

      // ── Network & Caching ─────────────────────────────────────────────────
      // Aggressive cache settings for reliable streaming on variable bitrates.
      mpv.setProperty('cache', 'yes');
      mpv.setProperty('cache-secs', '120');
      mpv.setProperty('demuxer-max-bytes', '300MiB');
      mpv.setProperty('demuxer-readahead-secs', '120');
      mpv.setProperty('demuxer-max-back-bytes', '50MiB');

      // ── Audio & Volume ────────────────────────────────────────────────────
      // Allow boosting volume up to 150% for quiet sources.
      mpv.setProperty('volume-max', '150');
      
      // Fallback strategies for unsupported audio codecs.
      mpv.setProperty('audio-fallback-to-null', 'yes');

      // --- Networking & Compatibility ---
      // Fixes "Refusing to load potentially unsafe URL" error
      mpv.setProperty('load-unsafe-playlists', 'yes');
      mpv.setProperty('user-agent', 'VLC/3.0.18 LibVLC/3.0.18');
      
      // MPV Internal logging off
      mpv.setProperty('log-level', 'no');
    } catch (e) {
      debugPrint('PlayerController: Failed to set MPV properties: $e');
    }
  }

  void _initializeManagers() {
    _trackManager = TrackManager(ref: ref, player: _player!);
    _applyTrackPreferences();

    _eventManager = EventManager(
      ref: ref,
      player: _player!,
      onStateChanged: () => _triggerStateUpdate(),
      onError: (err) => _handlePlayerError(err),
      onCompleted: () => _handlePlaybackCompleted(),
      onFormatDetected: (format) => _handleFormatDetected(format),
    );
    _eventManager!.initialize();

    _playbackManager = PlaybackManager(
      ref: ref, 
      player: _player!,
      castHandler: _castHandler,
      isCasting: () => state.value?.isCasting ?? false,
    );

    _initializationManager = InitializationManager(
      ref: ref,
      player: _player!,
      youtubeHandler: _youtubeHandler,
      rdHandler: _rdHandler,
      resolver: ref.read(unifiedStreamResolverProvider),
      tmdbService: ref.read(tmdbServiceProvider),
    );

    _liveTvHandler = LiveTvSourceHandler(_player!);
  }

  void _setupProgressTracking() {
    _progressTracker = PlayerProgressTracker(
      player: _player!,
      onProgress: (pos, dur) => _saveProgress(),
    )..start();

    if (mounted) {
      state = AsyncValue.data(CinemaPlayerState(
        controller: _controller!,
        availableStreams: const [],
        currentStream: null,
        title: params.episodeTitle ?? params.queryId,
        isResolving: true,
        activeAudioTrack: _player!.state.track.audio,
        activeSubtitleTrack: _player!.state.track.subtitle,
      ));
    }
  }

  Future<void> _handleYouTubeInitialization() async {
    final result = await _initializationManager!.initializeYouTube(params);
    if (mounted) {
      state = AsyncValue.data(CinemaPlayerState(
        controller: _controller!,
        availableStreams: result.candidates,
        currentStream: result.resolvedStream,
        title: result.title,
        activeAudioTrack: _player!.state.track.audio,
        activeSubtitleTrack: _player!.state.track.subtitle,
      ));
    }
  }

  Future<void> _handleVodInitialization() async {
    final vodResult = await _initializationManager!.initializeVod(
      params, 
      onStatusUpdate: _onProviderStatusUpdate,
      onMediaDetailsFetched: _onMediaDetailsFetched,
    );

    await _performPostInitialization(vodResult);
  }

  Future<void> _handleLiveTvInitialization() async {
    // Set up a bare "ready-but-idle" initial state.
    // LiveTvScreen's build method detects `currentStream == null && !isResolving`
    // and immediately calls `changeChannel` for the currently selected channel.
    if (mounted) {
      state = AsyncValue.data(CinemaPlayerState(
        controller: _controller!,
        availableStreams: const [],
        currentStream: null,
        title: params.episodeTitle ?? 'Live TV',
        isResolving: false,
      ));
    }
  }

  Future<void> changeChannel(Channel channel, {bool isFailover = false}) async {
    if (_player == null || _initializationManager == null) return;
    
    // Guard against multiple simultaneous failover attempts for the same issue.
    // However, ALWAYS allow manual changes (!isFailover) to proceed and override.
    if (isFailover && _isChangingChannel) {
      debugPrint('PlayerController: Skipping failover request; change already in progress.');
      return;
    }

    final requestId = ++_activeRequestId;
    _isChangingChannel = true;
    _currentChannel = channel;

    try {
      if (!isFailover) {
        // Reset failed markers and retry counters on manual selection
        for (final link in channel.links) {
          link.isFailed = false;
          link.softRetryCount = 0;
        }
      }

      // Identify which link we are trying to open
      _currentLink = null;
      if (channel.links.isNotEmpty) {
        _currentLink = channel.links.firstWhere((l) => !l.isFailed, orElse: () => channel.links.first);
      }

      // During failover, keep the last video frame visible ("freeze frame")
      // instead of showing the resolving spinner (black screen).
      if (mounted && requestId == _activeRequestId) {
        state = AsyncValue.data(state.valueOrNull?.copyWith(
          title: channel.name,
          isResolving: !isFailover,
          currentStream: isFailover ? state.valueOrNull?.currentStream : null,
          error: null,
        ) ?? CinemaPlayerState(
          controller: _controller!,
          availableStreams: const [],
          currentStream: null,
          title: channel.name,
          isResolving: true,
        ));
      }

      // 4. Initialize stream
      final settings = ref.read(settingsProvider);
      
      // Ensure previous stall watchdogs are stopped
      _liveTvHandler?.dispose();
      _liveTvHandler = LiveTvSourceHandler(_player!);
      
      final result = await _liveTvHandler!.initialize(
        channel, 
        settings,
        onStall: () => _handleLiveTvFailover('Stream stalled'),
      );
      
      // Only update state if this is still the most recent request
      if (mounted && requestId == _activeRequestId) {
        state = AsyncValue.data(state.value!.copyWith(
          currentStream: result.resolvedStream,
          isResolving: false,
          error: null,
        ));
      }
    } catch (e, st) {
      if (requestId == _activeRequestId) {
        _handleInitializationError(e, st);
      }
    } finally {
      // Only clear the guard if no newer request has started
      if (requestId == _activeRequestId) {
        _isChangingChannel = false;
      }
    }
  }

  /// Max retries on a connection error before rotating to the next link.
  /// EOS (stream ended) retries the same link infinitely since the server was working.
  static const int _maxErrorRetries = 1;

  Future<void> _handleLiveTvFailover(String error, {bool isConnectionError = false}) async {
    if (_currentChannel == null) return;
    
    // 1. Decide: persist on same link or rotate?
    if (_currentLink != null) {
      if (isConnectionError) {
        // Connection errors (timeout, refused, HTTP error): rotate after a few tries
        _currentLink!.softRetryCount++;
        if (_currentLink!.softRetryCount >= _maxErrorRetries) {
          debugPrint('PlayerController: Link unreachable after ${_currentLink!.softRetryCount} errors. Rotating.');
          _currentLink!.isFailed = true;
          _currentLink!.softRetryCount = 0;
        } else {
          debugPrint('PlayerController: Connection error (${_currentLink!.softRetryCount}/$_maxErrorRetries). Retrying SAME link.');
        }
      } else {
        // EOS (stream ended): the server WAS streaming. Retry same link forever.
        debugPrint('PlayerController: EOS on link. Retrying SAME link (server was active).');
        // Don't increment counter, don't mark as failed. Just retry.
      }
    }

    // 2. If all links are failed, reset and start over
    bool hasWorkingLinks = _currentChannel!.links.any((l) => !l.isFailed);
    if (!hasWorkingLinks) {
       debugPrint('PlayerController: All links exhausted. Restarting loop...');
       for (final link in _currentChannel!.links) {
         link.isFailed = false;
         link.softRetryCount = 0;
       }
    }
    
    // 3. Trigger the reconnection with no artificial delay.
    if (mounted) {
      await changeChannel(_currentChannel!, isFailover: true);
    }
  }

  void _onProviderStatusUpdate(List<ProviderSearchStatus> statuses) {
    if (!mounted) return;
    final currentState = state.valueOrNull;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(providerStatuses: statuses));
    }
  }

  void _onMediaDetailsFetched(Map<String, dynamic>? details) {
    _mediaDetails = details;
    _historyManager = PlayerHistoryManager(ref, params, details);
    
    if (mounted) {
      final currentState = state.valueOrNull;
      if (currentState != null) {
        state = AsyncValue.data(currentState.copyWith(
          title: details?['title'] ?? details?['name'] ?? currentState.title,
        ));
      }
    }
  }

  Future<void> _performPostInitialization(VodInitializationResult vodResult) async {
    await _ensureMediaCached();
    await _handleInitialSeek();
    final nextEpisode = await _calculateNextEpisode();

    if (mounted) {
      state = AsyncValue.data(CinemaPlayerState(
        controller: _controller!,
        availableStreams: vodResult.candidates,
        currentStream: vodResult.resolvedStream,
        title: _mediaDetails?['title'] ?? _mediaDetails?['name'] ?? ref.read(localizationsProvider).commonUnknown,
        nextEpisode: nextEpisode,
        providerStatuses: state.valueOrNull?.providerStatuses ?? const [],
        isAnime: vodResult.isAnime,
        activeAudioTrack: _player!.state.track.audio,
        activeSubtitleTrack: _player!.state.track.subtitle,
      ));
    }
    
    // Apply track preferences after state is updated with isAnime
    _applyTrackPreferences();
    unawaited(_trackManager?.ensurePreferredTrack(isAnime: vodResult.isAnime) ?? Future.value());
  }

  Future<void> _ensureMediaCached() async {
    final repo = ref.read(watchHistoryRepositoryProvider);
    final mainMediaItem = MediaItem(
      tmdbId: int.parse(params.queryId),
      mediaType: params.type == 'movie' ? MediaKind.movie : MediaKind.tv,
      title: _mediaDetails?['title'] ?? _mediaDetails?['name'] ?? ref.read(localizationsProvider).commonUnknown,
      posterPath: _mediaDetails?['poster_path'],
      backdropPath: _mediaDetails?['backdrop_path'],
      releaseDate: DateTime.tryParse(_mediaDetails?['release_date'] ?? _mediaDetails?['first_air_date'] ?? ''),
      updatedAt: DateTime.now(),
    );
    await repo.ensureMediaCached(mainMediaItem);
  }

  Future<void> _handleInitialSeek() async {
    if (params.startPosition > 0) {
      await _player!.stream.duration.firstWhere((d) => d.inSeconds > 0);
      await _player!.seek(Duration(seconds: params.startPosition));
    }
  }

  Future<NextEpisodeInfo?> _calculateNextEpisode() async {
    if (params.type != 'tv' || params.season == null || params.episode == null || _mediaDetails == null) {
      return null;
    }

    final nextEpResult = ref.read(seriesDomainServiceProvider).getNextEpisode(
      _mediaDetails!, 
      params.season!, 
      params.episode!,
    );
    
    if (!nextEpResult.isAired) return null;

    NextEpisodeInfo? next = nextEpResult.next;
    if (next != null) {
      final seasonDetails = await ref.read(tmdbServiceProvider).getSeasonDetails(int.parse(params.queryId), next.season);
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

  void _handleInitializationError(dynamic e, StackTrace st) {
    if (mounted) {
      final mapped = ref.read(errorMapperProvider).map(e);
      state = AsyncValue.error(mapped.message, st);
    }
  }


  Future<void> _saveProgress({bool force = false}) async {
    if (_player == null || _historyManager == null) return;
    
    await _historyManager!.saveProgress(
      position: _player!.state.position.inSeconds,
      duration: _player!.state.duration.inSeconds,
      actualSecondsWatched: _progressTracker?.actualSecondsWatched ?? 0,
      initialPosition: params.startPosition,
      isCompletionLogged: _isCompletionLogged,
      onCompletionLogged: (val) => _isCompletionLogged = val,
    );
  }

  Future<void> changeSource(StreamCandidate candidate) async {
    if (state.value == null || _player == null) return;

    state = AsyncValue.data(state.value!.copyWith(isResolving: true, error: null));
    
    try {
        final position = _player!.state.position;
        final resolvedStream = await _rdHandler.resolveAndMerge(
          candidate,
          season: params.season,
          episode: params.episode,
          absoluteEpisode: candidate.absoluteEpisode,
        );

        if (resolvedStream != null) {
          if (candidate.provider == 'YouTube') {
            final meta = candidate.metadata;
            String? localAudioPath;
            if (meta?.custom?['needsAudio'] == true) {
              localAudioPath = await _youtubeHandler.downloadAudioToTempFile();
            }

            await _player!.open(
              Media(resolvedStream.url, httpHeaders: _youtubeHandler.youtubeHeaders),
              play: false,
            );
            if (localAudioPath != null) {
              await _player!.setAudioTrack(AudioTrack.uri(localAudioPath));
            }
          } else {
            await _player!.open(
              Media(resolvedStream.url, httpHeaders: resolvedStream.headers),
              play: false,
            );
            unawaited(_trackManager?.ensurePreferredTrack(isAnime: state.valueOrNull?.isAnime ?? false) ?? Future.value());
          }

          final newDuration = await _player!.stream.duration.firstWhere((d) => d.inSeconds > 0);
          final seekTo = position.inSeconds < newDuration.inSeconds ? position : Duration(seconds: newDuration.inSeconds - 2);
          
          await _player!.seek(seekTo.isNegative ? Duration.zero : seekTo);
          await _player!.play();

          if (mounted) {
            state = AsyncValue.data(state.value!.copyWith(
              currentStream: resolvedStream,
              isResolving: false,
              error: null,
            ));
          }
        } else {
          throw Exception(ref.read(localizationsProvider).streamingErrorResolutionFailed);
        }
    } catch (e) {
      debugPrint("PlayerController: Error changing source: $e");
      if (mounted && state.value != null) {
        state = AsyncValue.data(state.value!.copyWith(
          isResolving: false,
          error: ref.read(errorMapperProvider).map(e).message,
        ));
      }
    }
  }

  void clearError() {
    if (state.value != null) {
      state = AsyncValue.data(state.value!.copyWith(error: null));
    }
  }

  Future<void> startCasting(CastDevice device) async {
    try {
      if (state.value == null) return;
      
      state = AsyncValue.data(state.value!.copyWith(
        isCasting: true,
        selectedCastDevice: device,
      ));

      await _playbackManager?.startCasting(
        device, 
        state.value!.currentStream!.candidate, 
        state.value!.title, 
        _player?.state.position ?? Duration.zero,
        (ResolvedStream resolvedStream) {
           // We can update state here if needed
           debugPrint('PlayerController: Cast stream resolved: ${resolvedStream.url}');
        },
        season: params.season,
        episode: params.episode,
        absoluteEpisode: state.value!.currentStream?.candidate.absoluteEpisode,
        detectedMimeType: state.value!.detectedMimeType,
      );

      _player?.pause();
    } catch (e) {
      debugPrint('PlayerController: Error starting cast: $e');
      stopCasting();
    }
  }

  Future<void> changeFile(int fileId) async {
    if (state.value == null || _player == null || state.value!.currentStream == null) return;

    state = AsyncValue.data(state.value!.copyWith(isResolving: true, error: null));

    try {
      final resolvedStream = await _rdHandler.resolveAndMerge(
        state.value!.currentStream!.candidate,
        absoluteEpisode: state.value!.currentStream!.candidate.absoluteEpisode,
        fileId: fileId,
      );
      
      if (resolvedStream != null) {
        await _player!.open(Media(resolvedStream.url), play: true);
        unawaited(_trackManager?.ensurePreferredTrack(isAnime: state.valueOrNull?.isAnime ?? false) ?? Future.value());
        
        state = AsyncValue.data(state.value!.copyWith(
          currentStream: resolvedStream,
          isResolving: false,
          error: null,
        ));
      } else {
        state = AsyncValue.data(state.value!.copyWith(
          isResolving: false,
          error: "Failed to resolve the selected file.",
        ));
      }
    } catch (e) {
      debugPrint("Error changing file: $e");
      if (state.value != null) {
        state = AsyncValue.data(state.value!.copyWith(
          isResolving: false,
          error: "Error changing file: ${e.toString()}",
        ));
      }
    }
  }


  Future<void> pause() async {
    await _playbackManager?.pause();
  }

  Future<void> play() async {
    await _playbackManager?.play();
  }

  Future<void> seek(Duration position) async {
    await _playbackManager?.seek(position);
  }

  Future<void> stopCasting() async {
    await _castHandler.stopCasting();
    final currentState = state.valueOrNull;
    if (currentState != null) {
      state = AsyncValue.data(currentState.copyWith(
        isCasting: false,
        selectedCastDevice: null,
        remotePosition: Duration.zero,
        remoteDuration: Duration.zero,
        remotePlaying: false,
      ));
    }
    _player?.play();
  }

  Future<void> _handlePlaybackCompleted() async {
    if (params.type == 'livetv') {
      if (_isChangingChannel) {
        debugPrint('PlayerController: Ignoring EOS during channel change.');
        return;
      }
      debugPrint('PlayerController: Live TV EOS. Retrying same link...');
      _handleLiveTvFailover('Stream ended (EOS)', isConnectionError: false);
      return;
    }

    // 1. Initial log
    await _saveProgress(force: true);
    
    // 2. Logic for next episode or auto-play can go here
    debugPrint('PlayerController: Playback finished. Ready for next actions.');
  }

  void _handlePlayerError(String error) {
    if (params.type == 'livetv') {
      if (_isChangingChannel) {
        debugPrint('PlayerController: Ignoring Error during channel change: $error');
        return;
      }
      // Connection error: retry same link a few times, then rotate.
      _handleLiveTvFailover(error, isConnectionError: true);
      return;
    }
    
    if (mounted) {
      state = AsyncValue.error(error, StackTrace.current);
    }
  }

  void _triggerStateUpdate() {
    if (mounted && state.hasValue) {
      state = AsyncValue.data(state.value!.copyWith(
        activeAudioTrack: _player?.state.track.audio,
        activeSubtitleTrack: _player?.state.track.subtitle,
      ));
    }
  }

  void updateSubtitleStyle(SubtitleStyle style) {
    if (mounted && state.hasValue) {
      state = AsyncValue.data(state.value!.copyWith(
        customSubtitleStyle: style,
      ));
    }
  }

  void playNextEpisode() {
    final next = state.valueOrNull?.nextEpisode;
    if (next == null || !mounted) return;

    // Use pushReplacement or similar via Navigator if possible, 
    // but better to let the UI handle navigation.
    // For now, keeping it here since UI calls it.
  }

  void _applyTrackPreferences() {
    _trackManager?.applyEnginePreferences(isAnime: state.valueOrNull?.isAnime ?? false);
  }

  void _handleFormatDetected(String? format) {
    if (format == null) return;
    
    final mimeType = MimeResolver.fromEngineFormat(format);
    if (mimeType != null && mimeType != state.valueOrNull?.detectedMimeType) {
      debugPrint('PlayerController: Engine detected format: $format -> $mimeType');
      if (mounted) {
        state = AsyncValue.data(state.value!.copyWith(
          detectedMimeType: mimeType,
        ));
      }
    }
  }
}
