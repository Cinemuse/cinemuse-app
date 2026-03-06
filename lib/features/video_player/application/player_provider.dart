
import 'dart:async';
import 'dart:io' as io;
import 'package:cinemuse_app/core/services/tmdb_service.dart';
import 'package:cinemuse_app/core/services/streaming/unified_stream_resolver.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/youtube_service.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';


import 'package:cast/cast.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/youtube_handler.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/rd_handler.dart';
import 'package:cinemuse_app/features/video_player/application/handlers/cast_handler.dart';
import 'package:cinemuse_app/features/video_player/application/language_mapper.dart';

// Convert back to StateNotifierProvider for compatibility/simplicity
final playerControllerProvider = StateNotifierProvider.family.autoDispose<PlayerController, AsyncValue<CinemaPlayerState>, PlayerParams>(
  (ref, params) => PlayerController(ref, params),
);

class PlayerController extends StateNotifier<AsyncValue<CinemaPlayerState>> {
  final Ref ref;
  final PlayerParams params;
  
  Player? _player;
  VideoController? _controller;
  StreamSubscription? _posSub;
  Timer? _saveTimer;
  Map<String, dynamic>? _mediaDetails;
  int _lastSavedPosition = 0;
  int _actualSecondsWatched = 0;
  int _lastPlaybackTick = -1;
  late int _initialPosition;
  bool _isCompletionLogged = false;
  late final YoutubeHandler _youtubeHandler;
  late final RdHandler _rdHandler;
  late final CastHandler _castHandler;

  PlayerController(this.ref, this.params) : super(const AsyncValue.loading()) {
    _initialPosition = params.startPosition;
    
    // Initialize Handlers
    _youtubeHandler = YoutubeHandler(ref.read(youtubeServiceProvider));
    _rdHandler = RdHandler(ref.read(unifiedStreamResolverProvider));
    _castHandler = CastHandler(ref.read(unifiedStreamResolverProvider));
    
    _initialize();
  }

  @override
  void dispose() {
    _saveProgress(force: true); // Try to save one last time
    _saveTimer?.cancel();
    _posSub?.cancel();
    _player?.dispose();
    _youtubeHandler.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      if (params.type == 'youtube') {
        final ytService = ref.read(youtubeServiceProvider);
        final streams = await ytService.getStreamQualities(params.queryId);
        
        if (streams.isEmpty) {
          throw Exception("Could not resolve YouTube streams");
        }

        // Sort by quality (highest first)
        // YouTube labels like 1080p, 720p, 480p, 360p
        // Sort by resolution (highest first)
        // Sort order to prioritize stability:
        // 1. HLS (Adaptive, Single Source) - Best
        // 2. Muxed (Single Source) - Reliable Fallback
        // 3. Separate A/V (High Res) - Manual Selection Only (can be unstable)
        streams.sort((a, b) {
           if (a['isHls'] == true) return -1;
           if (b['isHls'] == true) return 1;
           
           // If neither is HLS, prefer Muxed over Separate
           // We identify separate streams by checking if they have an 'audioUrl' key
           // Muxed streams do NOT have 'audioUrl' in our current logic (or we can add a flag)
           // Actually, let's use the fact that video-only streams have 'audioUrl'
           final aIsSeparate = a.containsKey('audioUrl');
           final bIsSeparate = b.containsKey('audioUrl');
           
           if (!aIsSeparate && bIsSeparate) return -1; // a is Muxed (better default)
           if (aIsSeparate && !bIsSeparate) return 1;  // b is Muxed (better default)

           return (b['res'] as int) - (a['res'] as int);
        });

        print('YT-DEBUG: Sorted qualities for playback: ${streams.map((s) => s['title']).toList()}');

        // Initial selection: Highest available but preferably not higher than 1080p for stability
        // HLS (1080p) or 1080p MP4 is preferred. 4K is allowed if manually selected later.
        final initialStream = streams.firstWhere(
          (s) => (s['res'] as int) <= 1080, 
          orElse: () => streams.first
        );
        
        print('YT-DEBUG: Initial Stream Selected: ${initialStream['title']} URL: ${initialStream['url']}');

        if (_player == null) {
          _player = Player();
          _controller = VideoController(
            _player!,
            configuration: VideoControllerConfiguration(
              vo: io.Platform.isAndroid ? 'gpu' : null,
            ),
          );
          
          _applyEnginePreferences();
          
          // Add debug listeners
          _player!.stream.error.listen((event) { 
            print('YT-DEBUG: Player Error: $event'); 
          });
          _player!.stream.log.listen((event) {
             if (event.level == 'error' || event.level == 'warn') {
               print('YT-DEBUG: Player Log: ${event.prefix} ${event.level} ${event.text}');
             }
          });
        }

        String? localAudioPath;
        if (initialStream['needsAudio'] == true) {
          localAudioPath = await _youtubeHandler.downloadAudioToTempFile();
        }

        await _player!.open(
          Media(initialStream['url'], httpHeaders: _youtubeHandler.youtubeHeaders),
          play: false,
        );
        
        if (localAudioPath != null) {
          print('YT-DEBUG: Setting Audio Track from local file: $localAudioPath');
          await _player!.setAudioTrack(AudioTrack.uri(localAudioPath));
        }

        await _player!.play();
        
        if (mounted) {
          state = AsyncValue.data(CinemaPlayerState(
            controller: _controller!,
            availableStreams: streams,
            currentStream: initialStream,
            title: initialStream['title'] ?? 'YouTube Video',
          ));
        }
        return;
      }

      // Rest of the existing RD logic...
      // 0. Get Settings
      // 0. Get Settings (Wait for init)
      var settings = ref.read(settingsProvider);
      int settingsAttempts = 0;
      
      // Poll for valid settings if RD is disabled (handling async init of SettingsNotifier)
      while (!settings.enableRealDebrid && settingsAttempts < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        settings = ref.read(settingsProvider);
        settingsAttempts++;
      }
      
      if (!settings.enableRealDebrid) {
        throw Exception("Real-Debrid is disabled in settings (or failed to load)");
      }
      
      final rdKey = settings.realDebridKey;
      if (rdKey.isEmpty) {
        throw Exception("Real-Debrid API Key is missing. Please check your settings.");
      }

      final resolver = ref.read(unifiedStreamResolverProvider);
      final tmdbService = ref.read(tmdbServiceProvider);
      
      // 1. Fetch Media Details (for history)
      _mediaDetails = await tmdbService.getMediaDetails(params.queryId, params.type);
      
      // 2. Search streams
      final candidates = await resolver.searchStreams(
        params.queryId, 
        params.type, 
        season: params.season, 
        episode: params.episode
      );

      if (candidates.isEmpty) {
        throw Exception("No streams found");
      }

      // Convert candidates to legacy maps for UI compatibility
      final streams = candidates.map((c) => c.toLegacyMap()).toList();

      // 3. Select initial stream (first cached, or first available)
      final initialCandidate = candidates.first;

      // 4. Resolve stream
      final streamData = await resolver.resolveStream(
        initialCandidate,
        season: params.season,
        episode: params.episode,
      );

      if (streamData == null || streamData['url'] == null) {
        throw Exception("Could not resolve initial stream");
      }

      // 4.5 Ensure media is cached (Natural retrieval point)
      final repo = ref.read(watchHistoryRepositoryProvider);
      
      // Cache the main media (Movie or TV show)
      final mainMediaItem = MediaItem(
        tmdbId: int.parse(params.queryId),
        mediaType: params.type == 'movie' ? MediaKind.movie : MediaKind.tv,
        title: _mediaDetails?['title'] ?? _mediaDetails?['name'] ?? 'Unknown',
        posterPath: _mediaDetails?['poster_path'],
        backdropPath: _mediaDetails?['backdrop_path'],
        releaseDate: DateTime.tryParse(_mediaDetails?['release_date'] ?? _mediaDetails?['first_air_date'] ?? ''),
        updatedAt: DateTime.now(),
      );
      if (_player == null) {
        _player = Player();
        _controller = VideoController(
          _player!,
          configuration: VideoControllerConfiguration(
            hwdec: io.Platform.isAndroid ? 'mediacodec' : 'auto',
            vo: io.Platform.isAndroid ? 'gpu' : null,
          ),
        );
        
        _applyEnginePreferences();
        
        // Setup Progress Listener
        _posSub = _player!.stream.position.listen((duration) {
          final seconds = duration.inSeconds;

          // Intent Detection: Track actual time watched
          if (_lastPlaybackTick != -1) {
            final delta = seconds - _lastPlaybackTick;
            // Standard playback delta is positive and small (~1s between emits usually, 
            // but we allow up to 2s for jitter/speedup). Seeking will produce large deltas.
            if (delta > 0 && delta <= 2) {
              _actualSecondsWatched += delta;
            }
          }
          _lastPlaybackTick = seconds;

          // Save every 15 seconds if position changed significantly
          if (seconds - _lastSavedPosition > 15 || seconds < _lastSavedPosition) { // Forward or Rewind
              _saveProgress();
              _lastSavedPosition = seconds;
          }
        });
      }

      print('Opening media: ${streamData['url']}');
      await _player!.open(Media(streamData['url'] as String), play: true);
      
      // Reactive preference check (backup for custom names)
      unawaited(_ensurePreferredTrack());
      
      if (params.startPosition > 0) {
        // Wait for usage duration to be available
        await _player!.stream.duration.firstWhere((d) => d.inSeconds > 0);
        await _player!.seek(Duration(seconds: params.startPosition));
      }

      // 6. Calculate Next Episode
      NextEpisodeInfo? nextEpisode;
      if (params.type == 'tv' && params.season != null && params.episode != null) {
        final seasons = _mediaDetails?['seasons'] as List? ?? [];
        final currentSeasonData = seasons.firstWhere(
          (s) => s['season_number'] == params.season,
          orElse: () => null,
        );
        
        if (currentSeasonData != null) {
          final episodeCount = currentSeasonData['episode_count'] as int? ?? 0;
          if (params.episode! < episodeCount) {
            // Get current season details for the episode title
            final seasonDetails = await tmdbService.getSeasonDetails(int.parse(params.queryId), params.season!);
            final episodes = seasonDetails?['episodes'] as List? ?? [];
            final nextEpData = episodes.firstWhere(
              (e) => e['episode_number'] == params.episode! + 1,
              orElse: () => null,
            );
            
            nextEpisode = NextEpisodeInfo(
              season: params.season!, 
              episode: params.episode! + 1,
              title: nextEpData?['name'],
            );
          } else {
            // Check if there is a next season
            final nextSeasonData = seasons.firstWhere(
              (s) => s['season_number'] == params.season! + 1,
              orElse: () => null,
            );
            if (nextSeasonData != null) {
              // Fetch next season details for the first episode title
              final nextSeasonDetails = await tmdbService.getSeasonDetails(int.parse(params.queryId), params.season! + 1);
              final episodes = nextSeasonDetails?['episodes'] as List? ?? [];
              final firstEpData = episodes.isNotEmpty ? episodes[0] : null;

              nextEpisode = NextEpisodeInfo(
                season: params.season! + 1, 
                episode: 1,
                title: firstEpData?['name'],
              );
            }
          }
        }
      }

      if (mounted) {
        state = AsyncValue.data(CinemaPlayerState(
          controller: _controller!,
          availableStreams: streams,
          currentStream: {...initialCandidate.toLegacyMap(), ...streamData!},
          title: _mediaDetails?['title'] ?? _mediaDetails?['name'] ?? 'Unknown',
          nextEpisode: nextEpisode,
          activeTorrentFiles: streamData['files'] != null ? List<Map<String, dynamic>>.from(streamData['files']) : const [],
          activeFileId: streamData['activeFileId'] as int?,
        ));
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> _saveProgress({bool force = false}) async {
    if (_player == null || _mediaDetails == null) return;
    
    final user = ref.read(authProvider).value;
    if (user == null) return;

    final position = _player!.state.position.inSeconds;
    final duration = _player!.state.duration.inSeconds;
    
    if (duration < 60) return;

    try {
      final repo = ref.read(watchHistoryRepositoryProvider);
      
      // Determine MediaKind
      final mediaType = params.type == 'movie' ? MediaKind.movie : MediaKind.tv;

      final mediaItem = MediaItem(
        tmdbId: int.parse(params.queryId),
        mediaType: mediaType,
        title: _mediaDetails?['title'] ?? _mediaDetails?['name'] ?? 'Unknown',
        posterPath: _mediaDetails?['poster_path'],
        backdropPath: _mediaDetails?['backdrop_path'],
        releaseDate: DateTime.tryParse(_mediaDetails?['release_date'] ?? _mediaDetails?['first_air_date'] ?? ''),
        updatedAt: DateTime.now(),
      );

      await repo.updateProgress(
        userId: user.id,
        media: mediaItem,
        progressSeconds: position,
        totalDuration: duration,
        season: params.season,
        episode: params.episode,
        seriesDetails: params.type == 'tv' ? _mediaDetails : null,
        actualSecondsWatched: _actualSecondsWatched,
        initialPosition: _initialPosition,
      );

      // 10. Proactively invalidate details screen providers if we just finished
      // This ensures that when the user goes back, the markers are already updated
      // even if the real-time stream hasn't pushed yet.
      final isFinished = (duration - position < 180) || (position / duration > 0.95);
      if (isFinished && !_isCompletionLogged) {
        _isCompletionLogged = true; // Lock in for this session
        
        if (params.type == 'tv') {
          final tmdbIdInt = int.tryParse(params.queryId);
          if (tmdbIdInt != null) {
            ref.invalidate(seriesWatchLogsProvider(tmdbIdInt));
            ref.invalidate(watchedEpisodesMapProvider(tmdbIdInt));
          }
        }
      }
    } catch (e) {
      print("Error saving progress: $e");
    }
  }

  Future<void> changeSource(Map<String, dynamic> newStream) async {
    final currentState = state.value;
    if (currentState == null || _player == null) return;

    try {
        if (params.type == 'youtube') {
          // ... existing youtube logic ...
          final position = _player!.state.position;
          
          String? localAudioPath;
          if (newStream['needsAudio'] == true) {
            localAudioPath = await _youtubeHandler.downloadAudioToTempFile();
          } else {
            _youtubeHandler.cleanup();
          }

          await _player!.open(
            Media(newStream['url'] as String, httpHeaders: _youtubeHandler.youtubeHeaders),
            play: false,
          );
          
          if (localAudioPath != null) {
            print('YT-DEBUG: Changing Audio Track from local file: $localAudioPath');
            await _player!.setAudioTrack(AudioTrack.uri(localAudioPath));
          }
          
          // Wait for duration to be available before seeking
          final newDuration = await _player!.stream.duration.firstWhere((d) => d.inSeconds > 0);
          final seekTo = position.inSeconds < newDuration.inSeconds ? position : Duration(seconds: newDuration.inSeconds - 2);
          
          await _player!.seek(seekTo.isNegative ? Duration.zero : seekTo);
          await _player!.play();

          state = AsyncValue.data(currentState.copyWith(
            currentStream: newStream,
          ));
          return;
        }

       final candidate = StreamCandidate.fromLegacyMap(newStream);
       final resolvedStream = await _rdHandler.resolveAndMerge(
         candidate,
         season: params.season,
         episode: params.episode,
         absoluteEpisode: candidate.absoluteEpisode,
       );

       if (resolvedStream != null) {
          final position = _player!.state.position;
          
          await _player!.open(Media(resolvedStream['url'] as String), play: true);
          
          unawaited(_ensurePreferredTrack());
          
          // Wait for duration to be available before seeking
          final newDuration = await _player!.stream.duration.firstWhere((d) => d.inSeconds > 0);
          final seekTo = position.inSeconds < newDuration.inSeconds ? position : Duration(seconds: newDuration.inSeconds - 2);
          
          await _player!.seek(seekTo.isNegative ? Duration.zero : seekTo);

          state = AsyncValue.data(currentState.copyWith(
            currentStream: resolvedStream,
            activeTorrentFiles: resolvedStream['files'] != null ? List<Map<String, dynamic>>.from(resolvedStream['files']) : const [],
            activeFileId: resolvedStream['activeFileId'] as int?,
          ));
       }
    } catch (e) {
      print("Error changing source: $e");
    }
  }

  Future<void> startCasting(CastDevice device) async {
    try {
      if (state.value == null) return;
      
      state = AsyncValue.data(state.value!.copyWith(
        isCasting: true,
        selectedCastDevice: device,
      ));

      await _castHandler.startCasting(
        device, 
        StreamCandidate.fromLegacyMap(state.value!.currentStream), 
        state.value!.title, 
        _player?.state.position ?? Duration.zero,
        (resolvedStream) {
          if (mounted) {
            state = AsyncValue.data(state.value!.copyWith(
              currentStream: resolvedStream,
              activeTorrentFiles: resolvedStream['files'] != null ? List<Map<String, dynamic>>.from(resolvedStream['files']) : const [],
              activeFileId: resolvedStream['activeFileId'] as int?,
            ));
          }
        },
        season: params.season,
        episode: params.episode,
        absoluteEpisode: state.value!.currentStream['absoluteEpisode'],
      );

      _player?.pause();
    } catch (e) {
      print('PlayerController: Error starting cast: $e');
      stopCasting();
    }
  }

  Future<void> changeFile(int fileId) async {
    final currentState = state.value;
    if (currentState == null || _player == null) return;

    try {
      print('PlayerController: Changing file to $fileId');
      final candidate = StreamCandidate.fromLegacyMap(currentState.currentStream);
      final resolvedStream = await _rdHandler.resolveAndMerge(
        candidate,
        absoluteEpisode: candidate.absoluteEpisode,
        fileId: fileId,
      );
      
      print('PlayerController: Resolved stream for file change: ${resolvedStream != null}');

      if (resolvedStream != null) {
        // Keep current position when switching files in same torrent (might be useful for split releases)
        // or starting from beginning if it's a completely different episode.
        // Usually, if a user manually picks a file, it's because auto-match failed.
        // Let's reset position if it's a manual switch in a pack.
        await _player!.open(Media(resolvedStream['url'] as String), play: true);
        
        unawaited(_ensurePreferredTrack());
        
        state = AsyncValue.data(currentState.copyWith(
          currentStream: resolvedStream,
          activeFileId: fileId,
        ));
      }
    } catch (e) {
      print("Error changing file: $e");
    }
  }

  Future<void> stopCasting() async {
    _castHandler.stopCasting();
    if (state.value != null) {
      state = AsyncValue.data(state.value!.copyWith(
        isCasting: false,
        selectedCastDevice: null,
      ));
    }
    _player?.play();
  }

  void _applyEnginePreferences() {
    if (_player == null) return;
    final lang = ref.read(settingsProvider).playerLanguage.toLowerCase();
    if (lang.isEmpty) return;

    final langCodes = LanguageMapper.getCodes(lang);
    final codesJoined = langCodes.join(',');

    try {
      // Set engine properties for instant matching (if codes are in metadata)
      (_player!.platform as dynamic).setProperty('alang', codesJoined);
      (_player!.platform as dynamic).setProperty('slang', codesJoined);
      print('PlayerController: Set engine preferences: $codesJoined');
    } catch (e) {
      print('PlayerController: Error setting engine props: $e');
    }
  }

  /// Backup logic for custom names (e.g. "English [Crunchyroll]")
  Future<void> _ensurePreferredTrack() async {
    if (_player == null) return;
    final lang = ref.read(settingsProvider).playerLanguage.toLowerCase();
    if (lang.isEmpty) return;

    try {
       // Wait short time for tracks to appear stabilizer
       await Future.delayed(const Duration(milliseconds: 500));
       await _player!.stream.tracks.firstWhere((t) => t.audio.isNotEmpty)
           .timeout(const Duration(seconds: 3));
           
       // Second small delay to ensure metadata (titles/langs) are parsed
       await Future.delayed(const Duration(milliseconds: 200));
           
       final tracks = _player!.state.tracks;
       
       // 1. Audio Check
       bool audioMatched = false;
       for (var track in tracks.audio) {
         if (track.id == 'auto' || track.id == 'no') continue;
         if (LanguageMapper.isMatch(track, lang)) {
           print('PlayerController: Explicitly Selecting Audio Match: ${track.title} [${track.id}]');
           await _player!.setAudioTrack(track);
           audioMatched = true;
           break;
         }
       }

       // If no match found and we are on 'auto', force the first real track for determinism
       if (!audioMatched && _player!.state.track.audio.id == 'auto') {
         final firstReal = tracks.audio.firstWhere((t) => t.id != 'auto' && t.id != 'no', orElse: () => _player!.state.track.audio);
         if (firstReal.id != 'auto') {
           print('PlayerController: No match, falling back to first audio track: ${firstReal.title}');
           await _player!.setAudioTrack(firstReal);
         }
       }

       // 2. Subtitle Check
       bool subtitleMatched = false;
       for (var track in tracks.subtitle) {
         if (track.id == 'auto' || track.id == 'no') continue;
         if (LanguageMapper.isMatch(track, lang)) {
           print('PlayerController: Direct Match Subtitle: ${track.title}');
           await _player!.setSubtitleTrack(track);
           subtitleMatched = true;
           break;
         }
       }
       
       // Fallback for subtitles if on 'auto' but no match
       if (!subtitleMatched && _player!.state.track.subtitle.id == 'auto') {
         // Subtitles usually default to 'no' if no match, which is fine
         // But let's be explicit if it's stuck on 'auto'
          final firstReal = tracks.subtitle.firstWhere((t) => t.id != 'auto' && t.id != 'no', orElse: () => _player!.state.track.subtitle);
          if (firstReal.id != 'auto') {
             print('PlayerController: No match, falling back to first subtitle: ${firstReal.title}');
             await _player!.setSubtitleTrack(firstReal);
          }
       }
    } catch (_) {
      // Timeout or no tracks, ignore
    }
  }

  bool _isLangMatch(dynamic track, String lang) {
    return LanguageMapper.isMatch(track, lang);
  }

  List<String> _getLanguageCodes(String lang) {
    return LanguageMapper.getCodes(lang);
  }
}
