import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:cinemuse_app/core/services/video/youtube_service.dart';
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

/// Unified handler for YouTube video stream resolution, playback initialization,
/// audio track extraction, and temp file caching.
class YouTubeSourceHandler {
  static const Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
    'Referer': 'https://www.youtube.com/',
  };

  final YoutubeService _ytService;
  final Player _player;
  String? _localAudioPath;

  YouTubeSourceHandler(this._ytService, this._player);

  YoutubeService get service => _ytService;
  Map<String, String> get youtubeHeaders => defaultHeaders;

  void cleanup() {
    final path = _localAudioPath;
    if (path != null) {
      _localAudioPath = null;
      try {
        final file = File(path);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (e, st) {
        developer.log(
          'Failed to delete temporary audio file: $path',
          name: 'VideoPlayer.YouTubeSourceHandler',
          error: e,
          stackTrace: st,
          level: 700,
        );
      }
    }
  }

  Future<String?> downloadAudioToTempFile() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/yt_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      cleanup();

      final resultPath = await _ytService.downloadAudioToFile(path);
      _localAudioPath = resultPath;
      return resultPath;
    } catch (e, st) {
      developer.log(
        'Error downloading audio',
        name: 'VideoPlayer.YouTubeSourceHandler',
        error: e,
        stackTrace: st,
        level: 900,
      );
      return null;
    }
  }

  void dispose() {
    cleanup();
  }

  Future<YouTubeInitializationResult> initialize(PlayerParams params) async {
    final streams = await _fetchAvailableStreams(params.queryId);

    final initialStream = _selectInitialStream(streams);
    final localAudioPath = await _prepareAudioIfNecessary(initialStream);

    await _openPlayer(initialStream, localAudioPath);

    final candidates = _createStreamCandidates(streams);
    final initialCandidate = _findInitialCandidate(candidates, initialStream);

    return YouTubeInitializationResult(
      candidates: candidates,
      resolvedStream: ResolvedStream(
        url: initialStream.url,
        provider: 'YouTube',
        candidate: initialCandidate,
        headers: youtubeHeaders,
      ),
      title: params.episodeTitle ?? initialStream.title,
    );
  }

  Future<List<YouTubeStreamQuality>> _fetchAvailableStreams(
    String queryId,
  ) async {
    final streams = await _ytService.getStreamQualities(queryId);
    if (streams.isEmpty) {
      throw Exception("Could not resolve YouTube streams");
    }
    return streams;
  }

  YouTubeStreamQuality _selectInitialStream(
    List<YouTubeStreamQuality> streams,
  ) {
    return streams.firstWhere(
      (s) => s.res <= 1080,
      orElse: () => streams.first,
    );
  }

  Future<String?> _prepareAudioIfNecessary(YouTubeStreamQuality stream) async {
    if (stream.needsAudio) {
      return await downloadAudioToTempFile();
    }
    return null;
  }

  Future<void> _openPlayer(
    YouTubeStreamQuality stream,
    String? localAudioPath,
  ) async {
    await _player.open(
      Media(stream.url, httpHeaders: youtubeHeaders),
      play: false,
    );

    if (localAudioPath != null) {
      await _player.setAudioTrack(AudioTrack.uri(localAudioPath));
    }

    await _player.play();
  }

  List<StreamCandidate> _createStreamCandidates(
    List<YouTubeStreamQuality> streams,
  ) {
    return streams
        .map(
          (s) => StreamCandidate(
            kind: StreamSourceKind.youtube,
            title: s.title,
            url: s.url,
            provider: 'YouTube',
            metadata: _buildYouTubeMetadata(s),
            headers: youtubeHeaders,
          ),
        )
        .toList();
  }

  StreamMetadata _buildYouTubeMetadata(YouTubeStreamQuality s) {
    return StreamMetadata(
      video: VideoMetadata(
        resolution: _parseResolution(s.res) ?? VideoResolution.unknown,
      ),
      audio: const AudioMetadata(),
      custom: {
        'needsAudio': s.needsAudio,
        'audioUrl': s.audioUrl,
        'isHls': s.isHls,
      },
    );
  }

  VideoResolution? _parseResolution(int res) {
    if (res >= 2160) return VideoResolution.r2160p;
    if (res >= 1080) return VideoResolution.r1080p;
    if (res >= 720) return VideoResolution.r720p;
    if (res >= 480) return VideoResolution.r480p;
    return VideoResolution.unknown;
  }

  StreamCandidate _findInitialCandidate(
    List<StreamCandidate> candidates,
    YouTubeStreamQuality initialStream,
  ) {
    return candidates.firstWhere(
      (c) => c.url == initialStream.url,
      orElse: () => candidates.first,
    );
  }
}
