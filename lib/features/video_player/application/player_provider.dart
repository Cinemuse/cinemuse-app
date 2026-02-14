
import 'dart:async';
import 'package:cinemuse_app/core/services/tmdb_service.dart';
import 'package:cinemuse_app/core/services/stream_resolver.dart';
import 'package:cinemuse_app/features/auth/application/auth_service.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


// Simple data class for params
class PlayerParams {
  final String queryId;
  final String type;
  final int? season;
  final int? episode;

  const PlayerParams(this.queryId, this.type, {this.season, this.episode});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerParams &&
          runtimeType == other.runtimeType &&
          queryId == other.queryId &&
          type == other.type &&
          season == other.season &&
          episode == other.episode;

  @override
  int get hashCode => Object.hash(queryId, type, season, episode);
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

  PlayerController(this.ref, this.params) : super(const AsyncValue.loading()) {
    _initialize();
  }

  @override
  void dispose() {
    _saveProgress(force: true); // Try to save one last time
    _saveTimer?.cancel();
    _posSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      // TODO: Get RD Key from secure storage / user settings
      const rdKey = "7XQSMICUQBIR7QB52AJWUVAQBNV4ZG55BEKNT5SNFAI566BXMFFQ"; 

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

      // 4. Resolve stream
      final streamData = await resolver.resolveStream(initialStream['magnet'], rdKey);
      if (streamData == null || streamData['url'] == null) {
        throw Exception("Could not resolve initial stream");
      }

      // 5. Initialize Player
      if (_player == null) {
        _player = Player();
        _controller = VideoController(_player!);
        
        // Setup Progress Listener
        _posSub = _player!.stream.position.listen((duration) {
          // Save every 15 seconds if position changed significantly
          final seconds = duration.inSeconds;
          if (seconds - _lastSavedPosition > 15 || seconds < _lastSavedPosition) { // Forward or Rewind
              _saveProgress();
              _lastSavedPosition = seconds;
          }
        });
      }

      await _player!.open(Media(streamData['url'] as String));
      
      if (mounted) {
        state = AsyncValue.data(CinemaPlayerState(
          controller: _controller!,
          availableStreams: streams,
          currentStream: initialStream,
        ));
      }
    } catch (e, st) {
      if (mounted) {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> _saveProgress({bool force = false}) async {
    // TODO: Re-implement progress saving against REST API
    // The previous Firebase-based repositories (movieRepository, seriesRepository)
    // were removed. This needs to be wired up to the new backend.
    if (_player == null || _mediaDetails == null) return;
    
    final user = ref.read(authProvider).value;
    if (user == null) return;

    final position = _player!.state.position.inSeconds;
    final duration = _player!.state.duration.inSeconds;
    
    if (duration < 60) return;

    try {
      // Progress saving is currently disabled - repositories not yet implemented
      print("Progress save skipped: repositories not yet available (pos: ${position}s / ${duration}s)");
    } catch (e) {
      print("Error saving progress: $e");
    }
  }

  Future<void> changeSource(Map<String, dynamic> newStream) async {
    final currentState = state.value;
    if (currentState == null || _player == null) return;

    try {
       const rdKey = "7XQSMICUQBIR7QB52AJWUVAQBNV4ZG55BEKNT5SNFAI566BXMFFQ"; 
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
       }
    } catch (e) {
      print("Error changing source: $e");
    }
  }
}

class CinemaPlayerState {
  final VideoController controller;
  final List<Map<String, dynamic>> availableStreams;
  final Map<String, dynamic> currentStream;

  CinemaPlayerState({
    required this.controller,
    required this.availableStreams,
    required this.currentStream,
  });

  CinemaPlayerState copyWith({
    VideoController? controller,
    List<Map<String, dynamic>>? availableStreams,
    Map<String, dynamic>? currentStream,
  }) {
    return CinemaPlayerState(
      controller: controller ?? this.controller,
      availableStreams: availableStreams ?? this.availableStreams,
      currentStream: currentStream ?? this.currentStream,
    );
  }
}
