import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/core/services/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_metadata.dart';
import 'package:media_kit/media_kit.dart';

class LiveTvInitializationResult {
  final ResolvedStream resolvedStream;
  final String title;

  LiveTvInitializationResult({
    required this.resolvedStream,
    required this.title,
  });
}

class LiveTvSourceHandler {
  final Player _player;

  LiveTvSourceHandler(this._player);

  Future<LiveTvInitializationResult> initialize(Channel channel) async {
    // 1. Optimize Player properties for Live TV
    _optimizeForLiveStreaming();

    // 2. Open the stream — fire-and-forget so we return immediately.
    //    The native BufferingIndicator handles the visual "buffering" spinner
    //    while mpv fills its buffer in the background.
    // ignore: unawaited_futures
    _player.open(Media(channel.url), play: true);

    // 3. Seek to the live edge as soon as the DVR window duration is known.
    //    FFmpeg's HLS demuxer defaults to live_start_index=0 (oldest segment),
    //    which can put us minutes behind live. Seeking to `duration - 10s`
    //    jumps straight to the live edge. We give up after 5 seconds in case
    //    the stream doesn't return a valid duration (e.g. pure live, no DVR).
    _seekToLiveEdge();

    // 4. Create a pseudo StreamCandidate/ResolvedStream so the rest of the app
    //    (like Casting) treats it identically to a VOD source.
    final candidate = StreamCandidate(
      title: channel.name,
      infoHash: channel.url,
      provider: 'Live TV',
      magnet: channel.url,
      metadata: StreamMetadata.empty(),
    );

    final resolvedStream = ResolvedStream(
      url: channel.url,
      provider: 'Live TV',
      candidate: candidate,
    );

    return LiveTvInitializationResult(
      resolvedStream: resolvedStream,
      title: channel.name,
    );
  }

  /// Seeks to the live edge (duration - 10s) as soon as the DVR window
  /// duration is known. For pure-live streams with no DVR this is a no-op.
  void _seekToLiveEdge() {
    _player.stream.duration
        .firstWhere((d) => d > const Duration(seconds: 30))
        .timeout(const Duration(seconds: 5))
        .then((duration) {
          final target = duration - const Duration(seconds: 10);
          if (target > Duration.zero) {
            _player.seek(target);
          }
        })
        .catchError((_) {
          // Stream has no DVR window or didn't expose duration — fine, stay where we are.
        });
  }

  void _optimizeForLiveStreaming() {
    try {
      final platform = _player.platform as dynamic;

      // --- Live Edge: Critical Fix ---
      // FFmpeg's HLS demuxer defaults to live_start_index=0, which means it
      // starts from the OLDEST segment in the DVR window — potentially minutes
      // behind live. Setting -3 tells it to start 3 segments (~18s) from NOW.
      // This eliminates the 10+ second traversal delay on stream open.
      platform.setProperty('demuxer-lavf-o', 'live_start_index=-3');

      // --- Minimal Pre-Buffer ---
      // Only require 1 second of data before starting playback.
      platform.setProperty('demuxer-readahead-secs', '1');
      platform.setProperty('demuxer-max-bytes', '1M');

      // --- No Pause on Cache Underrun ---
      // Keep playing even if the cache hits zero momentarily (live edge jitter).
      platform.setProperty('cache-pause', 'no');

      // --- Segement Prefetch (Better Zapping) ---
      // Pre-fetch the next playlist update while playing the current segment.
      platform.setProperty('prefetch-playlist', 'yes');

      // --- Cache ---
      platform.setProperty('cache', 'yes');
      platform.setProperty('cache-secs', '5');
    } catch (_) {
      // Ignore — some platforms don't expose mpv properties directly.
    }
  }
}
