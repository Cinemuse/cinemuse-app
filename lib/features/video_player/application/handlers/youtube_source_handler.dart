import 'dart:async';
import 'package:cinemuse_app/features/video_player/application/handlers/youtube_handler.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_metadata.dart';
import 'package:media_kit/media_kit.dart';

class YouTubeInitializationResult {
  final List<StreamCandidate> candidates;
  final ResolvedStream resolvedStream;
  final String title;

  YouTubeInitializationResult({
    required this.candidates,
    required this.resolvedStream,
    required this.title,
  });
}

class YouTubeSourceHandler {
  final YoutubeHandler _handler;
  final Player _player;

  YouTubeSourceHandler(this._handler, this._player);

  Future<YouTubeInitializationResult> initialize(PlayerParams params) async {
    final streams = await _fetchAvailableStreams(params.queryId);
    _sortStreamsByQuality(streams);
    
    final initialStream = _selectInitialStream(streams);
    final localAudioPath = await _prepareAudioIfNecessary(initialStream);

    await _openPlayer(initialStream, localAudioPath);
    
    final candidates = _createStreamCandidates(streams);
    final initialCandidate = _findInitialCandidate(candidates, initialStream);

    return YouTubeInitializationResult(
      candidates: candidates,
      resolvedStream: ResolvedStream(
        url: initialStream['url'],
        provider: 'YouTube',
        candidate: initialCandidate,
      ),
      title: initialStream['title'] ?? 'YouTube Video',
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAvailableStreams(String queryId) async {
    final streams = await _handler.service.getStreamQualities(queryId);
    if (streams.isEmpty) {
      throw Exception("Could not resolve YouTube streams");
    }
    return streams;
  }

  void _sortStreamsByQuality(List<Map<String, dynamic>> streams) {
    streams.sort((a, b) {
       if (a['isHls'] == true) return -1;
       if (b['isHls'] == true) return 1;
       
       final aIsSeparate = a.containsKey('audioUrl');
       final bIsSeparate = b.containsKey('audioUrl');
       
       if (!aIsSeparate && bIsSeparate) return -1;
       if (aIsSeparate && !bIsSeparate) return 1;

       return (b['res'] as int) - (a['res'] as int);
    });
  }

  Map<String, dynamic> _selectInitialStream(List<Map<String, dynamic>> streams) {
    return streams.firstWhere(
      (s) => (s['res'] as int) <= 1080, 
      orElse: () => streams.first
    );
  }

  Future<String?> _prepareAudioIfNecessary(Map<String, dynamic> stream) async {
    if (stream['needsAudio'] == true) {
      return await _handler.downloadAudioToTempFile();
    }
    return null;
  }

  Future<void> _openPlayer(Map<String, dynamic> stream, String? localAudioPath) async {
    await _player.open(
      Media(stream['url'], httpHeaders: _handler.youtubeHeaders),
      play: false,
    );
    
    if (localAudioPath != null) {
      await _player.setAudioTrack(AudioTrack.uri(localAudioPath));
    }

    await _player.play();
  }

  List<StreamCandidate> _createStreamCandidates(List<Map<String, dynamic>> streams) {
    return streams.map((s) => StreamCandidate(
      title: s['title'] ?? 'YouTube Stream',
      infoHash: s['url'],
      magnet: s['url'],
      provider: 'YouTube',
      metadata: StreamMetadata.empty().copyWithCustom(s),
    )).toList();
  }

  StreamCandidate _findInitialCandidate(List<StreamCandidate> candidates, Map<String, dynamic> initialStream) {
    return candidates.firstWhere(
      (c) => c.infoHash == initialStream['url'],
      orElse: () => candidates.first,
    );
  }
}
