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
import 'package:cinemuse_app/features/auth/application/auth_service.dart';

// Convert back to StateNotifierProvider for compatibility/simplicity
final playerControllerProvider = StateNotifierProvider.family
    .autoDispose<PlayerController, AsyncValue<CinemaPlayerState>, PlayerParams>(
      (ref, params) => PlayerController(ref, params),
    );

class PlayerController extends StateNotifier<AsyncValue<CinemaPlayerState>> {
  final Ref ref;
  final PlayerParams params;
  late PlayerParams resolvedParams;

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
  ProviderSubscription? _qualitySubscription;
  Completer<void>? _skipCompleter;

  /// Tracks candidate URLs already tried during auto-fallback to avoid retry loops.
  final Set<String> _exhaustedCandidateUrls = {};

  /// Optional callback to notify the UI of non-fatal player events (e.g. fallback snackbars).
  void Function(String message)? onNotification;

  PlayerHistoryManager get historyManager => _historyManager!;

  // --- Live TV Failover State ---
  bool _isChangingChannel = false;
  int _activeRequestId = 0;
  Channel? _currentChannel;
  StreamLink? _currentLink;

  // --- Auto-retry State ---
  int _retryCount = 0;
  static const int _maxRetries = 2;

  PlayerController(this.ref, this.params) : super(const AsyncValue.loading()) {
    resolvedParams = params;

    // Initialize Handlers
    _youtubeHandler = YoutubeHandler(ref.read(youtubeServiceProvider));
    _rdHandler = RdHandler(ref.read(unifiedStreamResolverProvider));
    _castHandler = CastHandler(ref, ref.read(unifiedStreamResolverProvider));

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
    _saveProgress(force: true);
    _eventManager?.dispose();
    _progressTracker?.dispose();
    _trackManager?.dispose();
    _player?.dispose();
    _youtubeHandler.dispose();
    _rdHandler.dispose();
    _qualitySubscription?.close();
    _castHandler.dispose();
    _liveTvHandler?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      _setupMediaEngine();

      // Guard against 0: the DB stores 0 as a sentinel for "no season/episode".
      // `params.season ?? 1` only handles null, not 0, so we must check explicitly.
      int resolvedSeason = (params.season == null || params.season! < 1)
          ? 1
          : params.season!;
      int resolvedEpisode = (params.episode == null || params.episode! < 1)
          ? 1
          : params.episode!;
      int resolvedStartPosition = params.startPosition ?? 0;

      final user = ref.read(authProvider).value;
      if (user != null &&
          (params.type == 'movie' ||
              params.type == 'tv' ||
              params.type == 'series')) {
        try {
          final repo = ref.read(watchHistoryRepositoryProvider);
          final history = await repo.getHistoryItem(user.id, params.queryId);
          if (history != null) {
            if (params.type == 'tv' || params.type == 'series') {
              // Re-apply the same 0-guard: history also stores 0 as sentinel.
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
        } catch (e) {
          // History fetch is best-effort: a network error or DB issue should
          // never prevent playback. Fall back to playing from the start.
        }
      }

      resolvedParams = params.copyWith(
        season: params.type == 'movie' ? null : resolvedSeason,
        episode: params.type == 'movie' ? null : resolvedEpisode,
        startPosition: resolvedStartPosition,
      );

      _initializeManagers();
      _setupProgressTracking();

      if (resolvedParams.type == 'youtube') {
        await _handleYouTubeInitialization();
        return;
      } else if (resolvedParams.type == 'livetv') {
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
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
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

      final isMobile = io.Platform.isAndroid || io.Platform.isIOS;

      // ── Video Sync & Smoothness ───────────────────────────────────────────
      // display-resample: syncs to the monitor's refresh rate, eliminates judder.
      // We disable this on Linux/WSL and mobile platforms as it can cause crashes
      // or heavy frame pacing/decoding latency on mobile SoCs.
      if (!io.Platform.isLinux && !isMobile) {
        mpv.setProperty('video-sync', 'display-resample');

        // Interpolation to smooth out frame pacing (reduces judder on 24fps content).
        mpv.setProperty('interpolation', 'yes');
        mpv.setProperty('tscale', 'oversample');
      } else if (isMobile) {
        // Fast, battery-efficient audio sync for mobile
        mpv.setProperty('video-sync', 'audio');
      }

      // ── Network & Caching ─────────────────────────────────────────────────
      // Optimized cache settings: fast startup and immediate playback
      // without blocking on huge initial pre-read buffers.
      mpv.setProperty('cache', 'yes');
      mpv.setProperty('cache-pause-initial', 'no');
      mpv.setProperty('cache-pause-wait', '1');

      if (isMobile) {
        mpv.setProperty('cache-secs', '20');
        mpv.setProperty('demuxer-max-bytes', '32MiB');
        mpv.setProperty('demuxer-readahead-secs', '10');
        mpv.setProperty('demuxer-max-back-bytes', '10MiB');
      } else {
        mpv.setProperty('cache-secs', '60');
        mpv.setProperty('demuxer-max-bytes', '128MiB');
        mpv.setProperty('demuxer-readahead-secs', '20');
        mpv.setProperty('demuxer-max-back-bytes', '30MiB');
      }

      // ── Reconnection ──────────────────────────────────────────────────────
      // Robust reconnection for handling timeouts after long pauses.
      mpv.setProperty('http-reconnect', 'yes');
      mpv.setProperty('reconnect-on-network-error', 'yes');
      mpv.setProperty('reconnect-on-http-error', 'all');

      // ── Audio & Volume ────────────────────────────────────────────────────
      // Allow boosting volume up to 150% for quiet sources.
      mpv.setProperty('volume-max', '150');

      // Fallback strategies for unsupported audio codecs.
      mpv.setProperty('audio-fallback-to-null', 'yes');

      // Force PulseAudio on Linux to avoid PipeWire issues in WSL
      if (io.Platform.isLinux) {
        mpv.setProperty('ao', 'pulse');
      }

      // --- Networking & Compatibility ---
      // Fixes "Refusing to load potentially unsafe URL" error
      mpv.setProperty('load-unsafe-playlists', 'yes');
      // Removed global user-agent override as it conflicts with custom headers (e.g., VixSrc user-agent)

      // --- Subtitle Rendering Fix for Windows d3d11va ---
      // With hardware decoding, video frames live on the GPU. MPV's subtitle compositor
      // normally blends subtitles *after* GPU output, which silently fails with d3d11va.
      // 'blend-subtitles: video' forces compositing at decode time (before hardware upload),
      // making subtitles compatible with any hwdec backend on any platform.
      mpv.setProperty('blend-subtitles', 'video');
    } catch (e) {
      debugPrint('PlayerController: Failed to set MPV properties: $e');
    }
  }

  void _initializeManagers() {
    _trackManager = TrackManager(
      ref: ref,
      player: _player!,
      params: resolvedParams,
    );
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

    if (resolvedParams.type == 'livetv') {
      _qualitySubscription = ref.listen(
        settingsProvider.select((s) => s.liveTvQuality),
        (prev, next) {
          if (prev != null && prev != next && _currentChannel != null) {
            debugPrint(
              'PlayerController: Quality preference changed to $next. Re-resolving channel...',
            );
            changeChannel(_currentChannel!);
          }
        },
      );
    }
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

  Future<void> _handleYouTubeInitialization() async {
    final result = await _initializationManager!.initializeYouTube(
      resolvedParams,
    );
    if (mounted) {
      state = AsyncValue.data(
        CinemaPlayerState(
          controller: _controller!,
          availableStreams: result.candidates,
          currentStream: result.resolvedStream,
          title: result.title,
          activeAudioTrack: _player!.state.track.audio,
          activeSubtitleTrack: _player!.state.track.subtitle,
          isLive: resolvedParams.type == 'livetv',
        ),
      );
    }
  }

  Future<void> _handleVodInitialization() async {
    _skipCompleter = Completer<void>();
    final vodResult = await _initializationManager!.initializeVod(
      resolvedParams,
      onStatusUpdate: _onProviderStatusUpdate,
      onMediaDetailsFetched: _onMediaDetailsFetched,
      skipTrigger: _skipCompleter!.future,
    );

    await _performPostInitialization(vodResult);
  }

  void skipResolution() {
    if (_skipCompleter != null && !_skipCompleter!.isCompleted) {
      _skipCompleter!.complete();
    }
  }

  Future<void> _handleLiveTvInitialization() async {
    // Set up a bare "ready-but-idle" initial state.
    // LiveTvScreen's build method detects `currentStream == null && !isResolving`
    // and immediately calls `changeChannel` for the currently selected channel.
    if (mounted) {
      state = AsyncValue.data(
        CinemaPlayerState(
          controller: _controller!,
          availableStreams: const [],
          currentStream: null,
          title: params.episodeTitle ?? 'Live TV',
          isResolving: false,
          isLive: true,
        ),
      );
    }
  }

  Future<void> changeChannel(Channel channel, {bool isFailover = false}) async {
    if (_player == null || _initializationManager == null) return;

    // Guard against multiple simultaneous failover attempts for the same issue.
    // However, ALWAYS allow manual changes (!isFailover) to proceed and override.
    if (isFailover && _isChangingChannel) {
      debugPrint(
        'PlayerController: Skipping failover request; change already in progress.',
      );
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

      // Identify which link we are trying to open, respecting preferred quality.
      _currentLink = null;
      if (channel.links.isNotEmpty) {
        final settings = ref.read(settingsProvider);
        final preferredQuality = settings.liveTvQuality;

        // Try to filter links by preferred quality
        final qualityLinks = channel.links
            .where((l) => l.quality == preferredQuality && !l.isFailed)
            .toList();

        if (qualityLinks.isNotEmpty) {
          _currentLink = qualityLinks.first;
        } else {
          // If no links match preferred quality (or all of them failed),
          // allow any non-failed link as fallback to avoid black screen.
          _currentLink = channel.links.firstWhere(
            (l) => !l.isFailed,
            orElse: () => channel.links.first,
          );
        }
      }

      // During failover, keep the last video frame visible ("freeze frame")
      // instead of showing the resolving spinner (black screen).
      if (mounted && requestId == _activeRequestId) {
        state = AsyncValue.data(
          state.valueOrNull?.copyWith(
                title: channel.name,
                isResolving: !isFailover,
                currentStream: isFailover
                    ? state.valueOrNull?.currentStream
                    : null,
                error: null,
                currentChannel: channel,
              ) ??
              CinemaPlayerState(
                controller: _controller!,
                availableStreams: const [],
                currentStream: null,
                title: channel.name,
                isResolving: true,
                isLive: true,
                currentChannel: channel,
              ),
        );
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
        state = AsyncValue.data(
          state.value!.copyWith(
            currentStream: result.resolvedStream,
            isResolving: false,
            error: null,
          ),
        );
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

  Future<void> _handleLiveTvFailover(
    String error, {
    bool isConnectionError = false,
  }) async {
    if (_currentChannel == null) return;

    // 1. Decide: persist on same link or rotate?
    if (_currentLink != null) {
      if (isConnectionError) {
        // Connection errors (timeout, refused, HTTP error): rotate after a few tries
        _currentLink!.softRetryCount++;
        if (_currentLink!.softRetryCount >= _maxErrorRetries) {
          debugPrint(
            'PlayerController: Link unreachable after ${_currentLink!.softRetryCount} errors. Rotating.',
          );
          _currentLink!.isFailed = true;
          _currentLink!.softRetryCount = 0;
        } else {
          debugPrint(
            'PlayerController: Connection error (${_currentLink!.softRetryCount}/$_maxErrorRetries). Retrying SAME link.',
          );
        }
      } else {
        // EOS (stream ended): the server WAS streaming. Retry same link forever.
        debugPrint(
          'PlayerController: EOS on link. Retrying SAME link (server was active).',
        );
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
      state = AsyncValue.data(
        currentState.copyWith(providerStatuses: statuses),
      );
    }
  }

  void _onMediaDetailsFetched(Map<String, dynamic>? details) {
    _mediaDetails = details;
    _historyManager = PlayerHistoryManager(ref, resolvedParams, details);

    if (mounted) {
      final currentState = state.valueOrNull;
      if (currentState != null) {
        final appLanguage = ref.read(settingsProvider).appLanguage;
        state = AsyncValue.data(
          currentState.copyWith(
            title: _extractLocalizedTitle(details, appLanguage),
          ),
        );
      }
    }
  }

  String _extractLocalizedTitle(
    Map<String, dynamic>? details,
    String languageCode,
  ) {
    if (details == null) {
      return resolvedParams.episodeTitle ?? resolvedParams.queryId;
    }
    return MediaItem.extractTitleFromTmdb(details, languageCode) ??
        resolvedParams.episodeTitle ??
        resolvedParams.queryId;
  }

  Future<void> _performPostInitialization(
    VodInitializationResult vodResult,
  ) async {
    if (mounted) {
      state = AsyncValue.data(
        CinemaPlayerState(
          controller: _controller!,
          availableStreams: vodResult.candidates,
          currentStream: vodResult.resolvedStream,
          title: _extractLocalizedTitle(
            _mediaDetails,
            ref.read(settingsProvider).appLanguage,
          ),
          nextEpisode: null,
          providerStatuses: state.valueOrNull?.providerStatuses ?? const [],
          isAnime: vodResult.isAnime,
          activeAudioTrack: _player!.state.track.audio,
          activeSubtitleTrack: _player!.state.track.subtitle,
          isLive: resolvedParams.type == 'livetv',
        ),
      );
    }

    // Reset retry count on successful initialization
    _retryCount = 0;

    // Apply track preferences after state is updated with isAnime
    _applyTrackPreferences();
    unawaited(
      _trackManager?.ensurePreferredTrack(isAnime: vodResult.isAnime) ??
          Future.value(),
    );

    unawaited(_ensureMediaCached());
    _handleInitialSeek();
    _loadNextEpisodeAsync();
  }

  Future<void> _loadNextEpisodeAsync() async {
    try {
      final nextEpisode = await _calculateNextEpisode();
      if (mounted && nextEpisode != null) {
        final current = state.valueOrNull;
        if (current != null) {
          state = AsyncValue.data(current.copyWith(nextEpisode: nextEpisode));
        }
      }
    } catch (_) {}
  }

  Future<void> _ensureMediaCached() async {
    final repo = ref.read(watchHistoryRepositoryProvider);
    final mainMediaItem = MediaItem(
      tmdbId: int.parse(resolvedParams.queryId),
      mediaType: resolvedParams.type == 'movie'
          ? MediaKind.movie
          : MediaKind.tv,
      titleIt: _extractLocalizedTitle(_mediaDetails, 'it'),
      titleEn: _extractLocalizedTitle(_mediaDetails, 'en'),
      posterPath: _mediaDetails?['poster_path'],
      backdropPath: _mediaDetails?['backdrop_path'],
      releaseDate: DateTime.tryParse(
        _mediaDetails?['release_date'] ??
            _mediaDetails?['first_air_date'] ??
            '',
      ),
      updatedAt: DateTime.now(),
    );
    await repo.saveMediaItem(mainMediaItem);
  }

  void _handleInitialSeek() {
    final startPos = resolvedParams.startPosition;
    if (startPos != null && startPos > 0) {
      _player!.stream.duration
          .firstWhere((d) => d.inSeconds > 0)
          .timeout(
            const Duration(seconds: 4),
            onTimeout: () => Duration.zero,
          )
          .then((_) {
            _player!.seek(Duration(seconds: startPos));
          })
          .catchError((_) {
            _player!.seek(Duration(seconds: startPos));
          });
    }
  }

  Future<NextEpisodeInfo?> _calculateNextEpisode() async {
    if (resolvedParams.type != 'tv' ||
        resolvedParams.season == null ||
        resolvedParams.episode == null ||
        _mediaDetails == null) {
      return null;
    }

    final nextEpResult = ref
        .read(seriesDomainServiceProvider)
        .getNextEpisode(
          _mediaDetails!,
          resolvedParams.season!,
          resolvedParams.episode!,
        );

    if (!nextEpResult.isAired) return null;

    NextEpisodeInfo? next = nextEpResult.next;
    if (next != null) {
      final seasonDetails = await ref
          .read(tmdbServiceProvider)
          .getSeasonDetails(int.parse(resolvedParams.queryId), next.season);
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
      initialPosition: resolvedParams.startPosition ?? 0,
      isCompletionLogged: _isCompletionLogged,
      onCompletionLogged: (val) => _isCompletionLogged = val,
    );
  }

  Future<void> changeSource(
    StreamCandidate candidate, {
    bool isManual = true,
  }) async {
    if (state.value == null || _player == null) return;

    // A manual source change clears the exhausted set so the user can retry anything.
    if (isManual) _exhaustedCandidateUrls.clear();

    state = AsyncValue.data(
      state.value!.copyWith(isResolving: true, error: null),
    );

    try {
      final position = _player!.state.position;

      switch (candidate.kind) {
        case StreamSourceKind.youtube:
          await _changeToYouTubeSource(candidate, position);
          break;
        case StreamSourceKind.vod:
          await _changeToVodSource(candidate, position);
          break;
        case StreamSourceKind.live:
          // Should not happen here since Live TV has changeChannel
          throw Exception(
            "Cannot change source on Live TV kind via changeSource.",
          );
      }
    } catch (e) {
      debugPrint("PlayerController: Error changing source: $e");
      if (mounted && state.value != null) {
        state = AsyncValue.data(
          state.value!.copyWith(
            isResolving: false,
            error: ref.read(errorMapperProvider).map(e).message,
          ),
        );
      }
    }
  }

  Future<void> _changeToYouTubeSource(
    StreamCandidate candidate,
    Duration position,
  ) async {
    final meta = candidate.metadata;
    String? localAudioPath;
    if (meta?.custom?['needsAudio'] == true) {
      localAudioPath = await _youtubeHandler.downloadAudioToTempFile();
    }

    final resolvedStream = ResolvedStream(
      url: candidate.url!,
      provider: candidate.provider,
      candidate: candidate,
      headers: _youtubeHandler.youtubeHeaders,
    );

    await _player!.open(
      Media(resolvedStream.url, httpHeaders: resolvedStream.headers),
      play: false,
    );

    if (localAudioPath != null) {
      await _player!.setAudioTrack(AudioTrack.uri(localAudioPath));
    }

    await _finalizeSourceChange(resolvedStream, position);
  }

  Future<void> _changeToVodSource(
    StreamCandidate candidate,
    Duration position,
  ) async {
    final resolvedStream = await _rdHandler.resolveAndMerge(
      candidate,
      season: resolvedParams.season,
      episode: resolvedParams.episode,
      absoluteEpisode: candidate.absoluteEpisode,
    );

    if (resolvedStream == null) {
      throw Exception(
        ref.read(localizationsProvider).streamingErrorResolutionFailed,
      );
    }

    await _player!.open(
      Media(resolvedStream.url, httpHeaders: resolvedStream.headers),
      play: false,
    );
    unawaited(
      _trackManager?.ensurePreferredTrack(
            isAnime: state.valueOrNull?.isAnime ?? false,
          ) ??
          Future.value(),
    );

    await _finalizeSourceChange(resolvedStream, position);
  }

  Future<void> _finalizeSourceChange(
    ResolvedStream resolvedStream,
    Duration position,
  ) async {
    final newDuration = await _player!.stream.duration.firstWhere(
      (d) => d.inSeconds > 0,
    );
    final seekTo = position.inSeconds < newDuration.inSeconds
        ? position
        : Duration(seconds: newDuration.inSeconds - 2);

    await _player!.seek(seekTo.isNegative ? Duration.zero : seekTo);
    await _player!.play();

    if (mounted) {
      _retryCount = 0; // Reset on manual source change
      state = AsyncValue.data(
        state.value!.copyWith(
          currentStream: resolvedStream,
          isResolving: false,
          error: null,
        ),
      );
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

      state = AsyncValue.data(
        state.value!.copyWith(isCasting: true, selectedCastDevice: device),
      );

      await _playbackManager?.startCasting(
        device,
        state.value!.currentStream!.candidate,
        state.value!.title,
        _player?.state.position ?? Duration.zero,
        (ResolvedStream resolvedStream) {
          // We can update state here if needed
          debugPrint(
            'PlayerController: Cast stream resolved: ${resolvedStream.url}',
          );
        },
        season: resolvedParams.season,
        episode: resolvedParams.episode,
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
    if (state.value == null ||
        _player == null ||
        state.value!.currentStream == null) {
      return;
    }

    state = AsyncValue.data(
      state.value!.copyWith(isResolving: true, error: null),
    );

    try {
      final resolvedStream = await _rdHandler.resolveAndMerge(
        state.value!.currentStream!.candidate,
        absoluteEpisode: state.value!.currentStream!.candidate.absoluteEpisode,
        fileId: fileId,
      );

      if (resolvedStream != null) {
        await _player!.open(Media(resolvedStream.url), play: true);
        unawaited(
          _trackManager?.ensurePreferredTrack(
                isAnime: state.valueOrNull?.isAnime ?? false,
              ) ??
              Future.value(),
        );

        state = AsyncValue.data(
          state.value!.copyWith(
            currentStream: resolvedStream,
            isResolving: false,
            error: null,
          ),
        );
      } else {
        state = AsyncValue.data(
          state.value!.copyWith(
            isResolving: false,
            error: "Failed to resolve the selected file.",
          ),
        );
      }
    } catch (e) {
      debugPrint("Error changing file: $e");
      if (state.value != null) {
        state = AsyncValue.data(
          state.value!.copyWith(
            isResolving: false,
            error: "Error changing file: ${e.toString()}",
          ),
        );
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
    _player?.play();
  }

  Future<void> _handlePlaybackCompleted() async {
    if (resolvedParams.type == 'livetv') {
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
    if (resolvedParams.type == 'livetv') {
      if (_isChangingChannel) {
        debugPrint(
          'PlayerController: Ignoring Error during channel change: $error',
        );
        return;
      }
      // Connection error: retry same link a few times, then rotate.
      _handleLiveTvFailover(error, isConnectionError: true);
      return;
    }

    // Filter out benign MPV errors that shouldn't crash the player state
    final lowerError = error.toLowerCase();
    if (lowerError.contains('already selected') ||
        lowerError.contains('track')) {
      debugPrint('PlayerController: Ignoring benign MPV error: $error');
      return;
    }

    if (mounted) {
      // 1. First: try soft-retry the same URL (handles transient network blips)
      final currentState = state.valueOrNull;
      if (currentState != null &&
          currentState.currentStream != null &&
          _retryCount < _maxRetries) {
        _retryCount++;
        debugPrint(
          'PlayerController: Auto-retrying playback (attempt $_retryCount/$_maxRetries) after error: $error',
        );
        _performSoftRetry();
        return;
      }

      // 2. Retries exhausted: auto-fallback to the next available candidate
      if (_tryNextCandidate()) return;

      // 3. All candidates exhausted: surface the error screen
      state = AsyncValue.error(error, StackTrace.current);
    }
  }

  /// Selects the next untried candidate from [availableStreams] and triggers
  /// [changeSource] on it. Returns `true` if a fallback was initiated.
  bool _tryNextCandidate() {
    final currentState = state.valueOrNull;
    if (currentState == null) return false;

    // Mark the current stream URL as exhausted
    final currentUrl = currentState.currentStream?.url;
    if (currentUrl != null) _exhaustedCandidateUrls.add(currentUrl);

    // Also mark the current candidate's source URL as exhausted
    final currentCandidateUrl = currentState.currentStream?.candidate.url;
    if (currentCandidateUrl != null) {
      _exhaustedCandidateUrls.add(currentCandidateUrl);
    }

    // Find the first stream not yet tried — safe null return if none exist
    final nextCandidate = currentState.availableStreams
        .where((c) => !_exhaustedCandidateUrls.contains(c.url))
        .firstOrNull;

    if (nextCandidate == null) return false;

    debugPrint(
      'PlayerController: Falling back to next candidate: ${nextCandidate.provider}',
    );
    _retryCount = 0; // Reset soft-retry counter for the new candidate

    final message = ref.read(localizationsProvider).playerTryingNextSource;
    onNotification?.call(message);

    // Initiate the source switch without clearing the exhausted set
    changeSource(nextCandidate, isManual: false);
    return true;
  }

  Future<void> _performSoftRetry() async {
    final currentState = state.valueOrNull;
    if (currentState == null ||
        currentState.currentStream == null ||
        _player == null) {
      return;
    }

    final lastPosition = _player!.state.position;
    final candidate = currentState.currentStream!.candidate;

    if (mounted) {
      state = AsyncValue.data(
        currentState.copyWith(
          isResolving: true,
          providerStatuses: const [], // Clear statuses to show simple spinner
          error: null,
        ),
      );
    }

    try {
      final resolvedStream = await _rdHandler.resolveAndMerge(
        candidate,
        season: resolvedParams.season,
        episode: resolvedParams.episode,
        absoluteEpisode: candidate.absoluteEpisode,
        fileId: currentState.currentStream?.activeFileId,
      );

      if (resolvedStream != null) {
        await _player!.open(
          Media(resolvedStream.url, httpHeaders: resolvedStream.headers),
          play: false,
        );

        // Wait for duration to be known before seeking
        final duration = await _player!.stream.duration
            .firstWhere((d) => d.inSeconds > 0)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => Duration.zero,
            );

        if (duration > Duration.zero) {
          final seekTo = lastPosition < duration ? lastPosition : Duration.zero;
          await _player!.seek(seekTo);
        }

        await _player!.play();

        if (mounted) {
          state = AsyncValue.data(
            state.value!.copyWith(
              currentStream: resolvedStream,
              isResolving: false,
            ),
          );
        }
      } else {
        throw Exception('Failed to re-resolve stream during auto-retry');
      }
    } catch (e) {
      debugPrint('PlayerController: Auto-retry failed: $e');
      if (mounted) {
        state = AsyncValue.error(e.toString(), StackTrace.current);
      }
    }
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

  void updateSubtitleStyle(SubtitleStyle style) {
    if (mounted && state.hasValue) {
      state = AsyncValue.data(
        state.value!.copyWith(customSubtitleStyle: style),
      );
    }
  }

  void updateSubtitleDelay(double delaySeconds) {
    if (_player == null || !mounted) return;
    try {
      final mpv = _player!.platform as dynamic;
      mpv.setProperty('sub-delay', delaySeconds.toString());
      if (state.hasValue) {
        state = AsyncValue.data(
          state.value!.copyWith(subtitleDelay: delaySeconds),
        );
      }
    } catch (e) {
      debugPrint('PlayerController: Failed to set sub-delay: \$e');
    }
  }

  void _applyTrackPreferences() {
    _trackManager?.applyEnginePreferences(
      isAnime: state.valueOrNull?.isAnime ?? false,
    );
  }

  void _handleFormatDetected(String? format) {
    if (format == null) return;

    final mimeType = MimeResolver.fromEngineFormat(format);
    if (mimeType != null && mimeType != state.valueOrNull?.detectedMimeType) {
      debugPrint(
        'PlayerController: Engine detected format: $format -> $mimeType',
      );
      if (mounted) {
        state = AsyncValue.data(
          state.value!.copyWith(detectedMimeType: mimeType),
        );
      }
    }
  }

  void setManualTrackSelection() {
    _trackManager?.setManualSelection();
  }
}
