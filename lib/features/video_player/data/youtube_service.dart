import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final youtubeServiceProvider = Provider((ref) => YoutubeService());

/// Strongly-typed domain model representing an available YouTube stream quality.
///
/// [title] is shown in the quality menu as is, so it only uses labels that
/// read the same in every language ("Auto", "1080p HD", "360p").
class YouTubeStreamQuality {
  final String title;
  final String url;
  final String quality;
  final int res;
  final String container;
  final String tag;
  final bool isHls;
  final bool needsAudio;
  final String? audioUrl;

  const YouTubeStreamQuality({
    required this.title,
    required this.url,
    required this.quality,
    required this.res,
    required this.container,
    required this.tag,
    this.isHls = false,
    this.needsAudio = false,
    this.audioUrl,
  });
}

/// Finds the playable streams of a YouTube video (trailers).
class YoutubeService {
  static const _tag = 'YoutubeService';

  /// The player mode YouTube's own test tools use. Without it YouTube refuses
  /// the HD picture and the separate sound of most videos, official trailers
  /// above all, when the player opens them.
  static const _testSuiteParams = '2AMB';

  /// The ways of asking YouTube, in order. They are tried one at a time
  /// because the library, given a list, always runs all of them and merges
  /// the answers, so a trailer would start from the iPhone way's HLS list.
  static final _clients = [
    _withTestSuiteParams(YoutubeApiClient.androidSdkless),
    _withTestSuiteParams(YoutubeApiClient.ios),
  ];

  static YoutubeApiClient _withTestSuiteParams(YoutubeApiClient client) =>
      YoutubeApiClient({
        ...client.payload,
        'params': _testSuiteParams,
      }, client.apiUrl);

  final YoutubeExplode _yt;

  YoutubeService({YoutubeExplode? client}) : _yt = client ?? YoutubeExplode();

  /// Returns the qualities of [videoId], best first (HLS, then by height).
  ///
  /// Video-only qualities carry the best audio-only stream in
  /// [YouTubeStreamQuality.audioUrl]; the player adds it as an external track.
  ///
  /// Throws a [StreamingFailure] when YouTube can't be reached, refuses the
  /// video (bot check, rate limit, region) or has no streams.
  Future<List<YouTubeStreamQuality>> getStreamQualities(String videoId) async {
    final manifest = await _manifestOf(videoId);
    final streams = _qualitiesFrom(manifest);
    AppLogger.debug(_tag, 'Found ${streams.length} streams for $videoId');
    if (streams.isEmpty) {
      throw StreamingFailure('YouTube has no streams for video $videoId');
    }
    return streams;
  }

  /// The answer of the first way of asking that gets one.
  Future<StreamManifest> _manifestOf(String videoId) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (final client in _clients) {
      try {
        return await _yt.videos.streamsClient.getManifest(
          videoId,
          ytClients: [client],
        );
      } catch (e, st) {
        AppLogger.warn(
          _tag,
          'A way of asking YouTube failed for video $videoId',
          error: e,
          stackTrace: st,
        );
        lastError = e;
        lastStackTrace = st;
      }
    }
    throw StreamingFailure(
      'YouTube gave no manifest for video $videoId',
      cause: lastError,
      stackTrace: lastStackTrace,
    );
  }

  List<YouTubeStreamQuality> _qualitiesFrom(StreamManifest manifest) {
    final streams = <YouTubeStreamQuality>[];

    if (manifest.hls.isNotEmpty) {
      streams.add(
        YouTubeStreamQuality(
          title: 'Auto',
          url: manifest.hls.first.url.toString(),
          quality: 'hls',
          res: 1080,
          container: 'm3u8',
          tag: 'youtube',
          isHls: true,
        ),
      );
    }

    bool hasHeight(int res) => streams.any((e) => e.res == res && !e.isHls);

    // Muxed streams have sound built in and YouTube refuses them less often,
    // so they come first: a video-only stream of the same height is dropped.
    for (final s in manifest.muxed) {
      final res = s.videoResolution.height;
      if (hasHeight(res)) continue;
      streams.add(
        YouTubeStreamQuality(
          title: '${res}p',
          url: s.url.toString(),
          quality: s.videoQuality.name,
          res: res,
          container: s.container.name,
          tag: 'youtube',
        ),
      );
    }

    // Video-only streams have the highest qualities but no sound, so they
    // are only usable when there is an audio-only stream to add.
    final audio = _bestAudio(manifest.audioOnly);
    if (audio != null) {
      for (final s in manifest.videoOnly) {
        final res = s.videoResolution.height;
        if (hasHeight(res)) continue;
        streams.add(
          YouTubeStreamQuality(
            title: '${res}p ${res >= 720 ? 'HD' : 'SD'}',
            url: s.url.toString(),
            audioUrl: audio.url.toString(),
            quality: s.videoQuality.name,
            res: res,
            container: s.container.name,
            tag: 'youtube',
            needsAudio: true,
          ),
        );
      }
    }

    streams.sort((a, b) {
      if (a.isHls) return -1;
      if (b.isHls) return 1;
      return b.res - a.res;
    });
    return streams;
  }

  /// The highest-bitrate audio-only stream, preferring the original
  /// (default) track. The library's `withHighestBitrate()` throws when there
  /// is no audio or only dubbed tracks.
  static AudioOnlyStreamInfo? _bestAudio(List<AudioOnlyStreamInfo> audio) {
    final original = audio.where(
      (a) => a.audioTrack == null || a.audioTrack!.audioIsDefault,
    );
    final pool = original.isEmpty ? audio : original;
    return pool.isEmpty ? null : pool.sortByBitrate().first;
  }

  void dispose() {
    _yt.close();
  }
}
