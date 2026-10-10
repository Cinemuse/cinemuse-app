import 'package:cinemuse_app/features/video_player/data/youtube_service.dart';
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

/// Resolves a YouTube video and opens it in the player.
class YouTubeSourceHandler {
  static const Map<String, String> defaultHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
    'Referer': 'https://www.youtube.com/',
  };

  final YoutubeService _ytService;
  final Player _player;

  YouTubeSourceHandler(this._ytService, this._player);

  YoutubeService get service => _ytService;
  Map<String, String> get youtubeHeaders => defaultHeaders;

  Future<YouTubeInitializationResult> initialize(PlayerParams params) async {
    final streams = await _ytService.getStreamQualities(params.queryId);

    final initialStream = _selectInitialStream(streams);
    await openStream(initialStream.url, audioUrl: initialStream.audioUrl);

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

  YouTubeStreamQuality _selectInitialStream(
    List<YouTubeStreamQuality> streams,
  ) {
    return streams.firstWhere(
      (s) => s.res <= 1080,
      orElse: () => streams.first,
    );
  }

  /// Opens [url] in the player. Video-only streams pass [audioUrl]: the
  /// player streams it as an external audio track, so playback starts at
  /// once instead of after downloading the whole audio file (REV-236).
  Future<void> openStream(String url, {String? audioUrl}) async {
    await _player.open(Media(url, httpHeaders: youtubeHeaders), play: false);
    if (audioUrl != null) {
      await _player.setAudioTrack(AudioTrack.uri(audioUrl));
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
