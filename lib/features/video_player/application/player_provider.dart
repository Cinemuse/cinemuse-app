
import 'dart:async';
import 'dart:io';
import 'package:cinemuse_app/core/services/tmdb_service.dart';
import 'package:cinemuse_app/core/services/stream_resolver.dart';
import 'package:cinemuse_app/core/services/youtube_service.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';


// Simple data class for params
class PlayerParams {
  final String queryId;
  final String type;
  final int? season;
  final int? episode;
  final String? episodeTitle;
  final int startPosition;

  const PlayerParams(this.queryId, this.type, {
    this.season, 
    this.episode, 
    this.episodeTitle,
    this.startPosition = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerParams &&
          runtimeType == other.runtimeType &&
          queryId == other.queryId &&
          type == other.type &&
          season == other.season &&
          episode == other.episode &&
          episodeTitle == other.episodeTitle &&
          startPosition == other.startPosition;

  @override
  int get hashCode => Object.hash(queryId, type, season, episode, episodeTitle, startPosition);
}

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
  File? _audioTempFile;

  // YouTube CDN requires proper headers to serve video streams
  static const _ytHeaders = {
    'User-Agent': 'com.google.android.youtube/19.02.39 (Linux; U; Android 14) gzip',
  };

  PlayerController(this.ref, this.params) : super(const AsyncValue.loading()) {
    _initialPosition = params.startPosition;
    _initialize();
  }

  @override
  void dispose() {
    _saveProgress(force: true); // Try to save one last time
    _saveTimer?.cancel();
    _posSub?.cancel();
    _player?.dispose();
    _cleanupAudioTempFile();
    super.dispose();
  }

  void _cleanupAudioTempFile() {
    try {
      _audioTempFile?.deleteSync();
      _audioTempFile = null;
    } catch (_) {}
  }



  /// Downloads the audio stream to a local temp file using youtube_explode_dart's
  /// authenticated stream client. Raw YouTube URLs return 403 when accessed directly
  /// by the player as external tracks (due to missing headers).
  Future<String> _downloadAudioToTempFile() async {
    _cleanupAudioTempFile();
    
    final tempDir = Directory.systemTemp;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    _audioTempFile = File('${tempDir.path}${Platform.pathSeparator}yt_audio_$timestamp.webm');
    
    final ytService = ref.read(youtubeServiceProvider);
    await ytService.downloadAudioToFile(_audioTempFile!.path);
    
    return _audioTempFile!.path;
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
          _controller = VideoController(_player!);
          
          // Add debug listeners
          _player!.stream.error.listen((event) { 
            print('YT-DEBUG: Player Error: $event'); 
          });
          _player!.stream.log.listen((event) {
             // Filter out noisy logs, keep warnings/errors
             if (event.level == 'error' || event.level == 'warn') {
               print('YT-DEBUG: Player Log: ${event.prefix} ${event.level} ${event.text}');
             }
          });
        }

        // For video-only HD streams, download audio to a local temp file
        // using youtube_explode_dart's authenticated stream client.
        String? localAudioPath;
        if (initialStream['needsAudio'] == true) {
          localAudioPath = await _downloadAudioToTempFile();
        }

        // Open video PAUSED with YouTube headers
        await _player!.open(
          Media(initialStream['url'], httpHeaders: _ytHeaders),
          play: false,
        );
        
        // Attach local audio file if we downloaded one
        if (localAudioPath != null) {
          print('YT-DEBUG: Setting Audio Track from local file: $localAudioPath');
          await _player!.setAudioTrack(AudioTrack.uri(localAudioPath));
        }

        // Now start playback
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

      final resolver = ref.read(streamResolverProvider);
      final tmdbService = ref.read(tmdbServiceProvider);
      
      // 1. Fetch Media Details (for history)
      _mediaDetails = await tmdbService.getMediaDetails(params.queryId, params.type);
      
      // 2. Search streams
      final streams = await resolver.searchStreams(
        params.queryId, 
        params.type, 
        rdKey, 
        season: params.season, 
        episode: params.episode
      );

      if (streams.isEmpty) {
        throw Exception("No streams found");
      }

      // 3. Select initial stream (first cached, or first available)
      final initialStream = streams.first;

      // 4. Resolve stream with retry
      Map<String, dynamic>? streamData;
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          streamData = await resolver.resolveStream(initialStream['magnet'], rdKey);
          if (streamData != null && streamData['url'] != null) {
            break; // Success
          }
        } catch (e) {
          print('Stream resolution attempt ${retryCount + 1} failed: $e');
        }
        
        retryCount++;
        if (retryCount < maxRetries) {
          await Future.delayed(Duration(seconds: retryCount)); // Exponential backoff-ish
        }
      }

      if (streamData == null || streamData['url'] == null) {
        throw Exception("Could not resolve initial stream after $maxRetries attempts");
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
      await repo.ensureMediaCached(mainMediaItem);

      // 5. Initialize Player
      if (_player == null) {
        _player = Player();
        _controller = VideoController(_player!);
        
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
      await _player!.open(Media(streamData['url'] as String), play: true); // Start playing
      
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
          currentStream: initialStream,
          title: _mediaDetails?['title'] ?? _mediaDetails?['name'] ?? 'Unknown',
          nextEpisode: nextEpisode,
        ));
        
        // Apply language preference after state is set and tracks are likely loaded
        _applyLanguagePreference().then((_) => _applySubtitlePreference());
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
          final position = _player!.state.position;
          
          // Download audio to temp file for video-only streams
          String? localAudioPath;
          if (newStream['needsAudio'] == true) {
            localAudioPath = await _downloadAudioToTempFile();
          } else {
            _cleanupAudioTempFile();
          }

          // Open new stream PAUSED with YouTube headers
          await _player!.open(
            Media(newStream['url'] as String, httpHeaders: _ytHeaders),
            play: false,
          );
          
          // Attach local audio file
          if (localAudioPath != null) {
            print('YT-DEBUG: Changing Audio Track from local file: $localAudioPath');
            await _player!.setAudioTrack(AudioTrack.uri(localAudioPath));
          }
          
          await _player!.seek(position);
          await _player!.play();

          state = AsyncValue.data(currentState.copyWith(
            currentStream: newStream,
          ));
          return;
        }

       final rdKey = ref.read(settingsProvider).realDebridKey;
       if (rdKey.isEmpty) {
         throw Exception("Real-Debrid API Key is missing");
       }
       final resolver = ref.read(streamResolverProvider);

       // Resolve new URL
       final streamData = await resolver.resolveStream(newStream['magnet'], rdKey);
       if (streamData != null && streamData['url'] != null) {
          final position = _player!.state.position;
          
          await _player!.open(Media(streamData['url'] as String), play: true);
          await _player!.seek(position);

          state = AsyncValue.data(currentState.copyWith(
            currentStream: newStream,
          ));
          
          _applyLanguagePreference().then((_) => _applySubtitlePreference());
       }
    } catch (e) {
      print("Error changing source: $e");
    }
  }

  Future<void> _applyLanguagePreference() async {
    if (_player == null) return;
    
    // Retry loop to wait for tracks to be parsed by the engine
    int attempts = 0;
    List<AudioTrack> tracks = [];
    while (attempts < 6) { // 6 * 500ms = 3s max wait
       tracks = _player!.state.tracks.audio;
       // Filter out 'no' and 'auto' tracks
       final hasRealTracks = tracks.any((t) => t.id != 'no' && t.id != 'auto');
       if (hasRealTracks) break;
       
       await Future.delayed(const Duration(milliseconds: 500));
       attempts++;
    }

    if (tracks.isEmpty) return;
    
    final settings = ref.read(settingsProvider);
    final prefLang = settings.playerLanguage.toLowerCase();
    
    // 1. Try to find a match for preferred language
    AudioTrack? bestMatch;
    for (final track in tracks) {
      if (track.id == 'no' || track.id == 'auto') continue;
      
      final title = (track.title ?? '').toLowerCase();
      final lang = (track.language ?? '').toLowerCase();
      
      if (title.contains(prefLang) || lang.contains(prefLang)) {
        bestMatch = track;
        break;
      }
      
      if (prefLang == 'it' && (title.contains('ita') || title.contains('italian'))) {
        bestMatch = track;
        break;
      }
      if (prefLang == 'en' && (title.contains('eng') || title.contains('english'))) {
        bestMatch = track;
        break;
      }
    }
    
    // 2. Fallback: select the first available real track if no match found
    if (bestMatch == null) {
      bestMatch = tracks.firstWhere((t) => t.id != 'no' && t.id != 'auto', orElse: () => tracks.first);
    }
    
    if (bestMatch != null && bestMatch.id != 'auto') {
      print('Proactively selecting audio track: ${bestMatch.title ?? bestMatch.language ?? bestMatch.id}');
      await _player!.setAudioTrack(bestMatch);
    }
  }

  Future<void> _applySubtitlePreference() async {
    if (_player == null) return;
    
    // Wait for tracks if not already populated (re-using the logic from audio might be better but let's be safe)
    int attempts = 0;
    List<SubtitleTrack> tracks = [];
    while (attempts < 6) {
       tracks = _player!.state.tracks.subtitle;
       final hasRealTracks = tracks.any((t) => t.id != 'no' && t.id != 'auto');
       if (hasRealTracks) break;
       await Future.delayed(const Duration(milliseconds: 500));
       attempts++;
    }

    if (tracks.isEmpty) return;
    
    final settings = ref.read(settingsProvider);
    final prefLang = settings.playerLanguage.toLowerCase();
    
    // Check current audio language
    final currentAudio = _player!.state.track.audio;
    final audioTitle = (currentAudio.title ?? '').toLowerCase();
    final audioLang = (currentAudio.language ?? '').toLowerCase();
    final audioId = currentAudio.id.toLowerCase();

    bool audioMatch = audioTitle.contains(prefLang) || audioLang.contains(prefLang) || audioId == prefLang;
    // Special check for ITA/Italian
    if (prefLang == 'it' && (audioTitle.contains('ita') || audioTitle.contains('italian'))) audioMatch = true;
    if (prefLang == 'en' && (audioTitle.contains('eng') || audioTitle.contains('english'))) audioMatch = true;

    // If audio matches preference, we usually don't need subtitles
    if (audioMatch) {
      print('Audio matches preference ($prefLang), disabling subtitles.');
      await _player!.setSubtitleTrack(SubtitleTrack.no());
      return;
    }

    // Otherwise, try to find a subtitle track for the preferred language
    SubtitleTrack? bestMatch;
    for (final track in tracks) {
      if (track.id == 'no' || track.id == 'auto') continue;
      
      final title = (track.title ?? '').toLowerCase();
      final lang = (track.language ?? '').toLowerCase();
      
      if (title.contains(prefLang) || lang.contains(prefLang)) {
        bestMatch = track;
        break;
      }
      
      if (prefLang == 'it' && (title.contains('ita') || title.contains('italian'))) {
        bestMatch = track;
        break;
      }
      if (prefLang == 'en' && (title.contains('eng') || title.contains('english'))) {
        bestMatch = track;
        break;
      }
    }
    
    if (bestMatch != null) {
      print('Auto-enabling subtitle track: ${bestMatch.title ?? bestMatch.language ?? bestMatch.id}');
      await _player!.setSubtitleTrack(bestMatch);
    } else {
      print('No matching subtitle found for $prefLang.');
    }
  }

}

class NextEpisodeInfo {
  final int season;
  final int episode;
  final String? title;

  NextEpisodeInfo({required this.season, required this.episode, this.title});
}

class CinemaPlayerState {
  final VideoController controller;
  final List<Map<String, dynamic>> availableStreams;
  final Map<String, dynamic> currentStream;
  final String title;
  final NextEpisodeInfo? nextEpisode;

  CinemaPlayerState({
    required this.controller,
    required this.availableStreams,
    required this.currentStream,
    required this.title,
    this.nextEpisode,
  });

  CinemaPlayerState copyWith({
    VideoController? controller,
    List<Map<String, dynamic>>? availableStreams,
    Map<String, dynamic>? currentStream,
    String? title,
    NextEpisodeInfo? nextEpisode,
  }) {
    return CinemaPlayerState(
      controller: controller ?? this.controller,
      availableStreams: availableStreams ?? this.availableStreams,
      currentStream: currentStream ?? this.currentStream,
      title: title ?? this.title,
      nextEpisode: nextEpisode ?? this.nextEpisode,
    );
  }
}
