import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
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

  Future<LiveTvInitializationResult> initialize(Channel channel, UserSettings settings) async {
    // 1. Optimize Player properties for Live TV
    _optimizeForLiveStreaming(settings);

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
          // Seek to 5s before the end for better stability across different streams
          final target = duration - const Duration(seconds: 5);
          if (target > Duration.zero) {
            _player.seek(target);
          }
        })
        .catchError((_) {
          // Stream has no DVR window or didn't expose duration — fine, stay where we are.
        });
  }

  void _optimizeForLiveStreaming(UserSettings settings) {
    try {
      final platform = _player.platform as dynamic;

      // 1. DVR Window & Cache size
      // Convert MB to Bytes for MPV
      final bufferBytes = settings.liveTvBufferSize * 1024 * 1024;
      
      // demuxer-max-bytes: how much to buffer ahead
      // We set it to 10% of total buffer or at least 100MB
      final forwardBuffer = (bufferBytes * 0.1).clamp(100 * 1024 * 1024, bufferBytes).toInt();
      // demuxer-max-back-bytes: how much to keep behind (the actual DVR)
      final backBuffer = (bufferBytes - forwardBuffer).clamp(0, bufferBytes).toInt();

      platform.setProperty('demuxer-max-bytes', forwardBuffer.toString());
      platform.setProperty('demuxer-max-back-bytes', backBuffer.toString());

      // 2. Disk Caching
      if (settings.enableLiveTvDiskCache) {
        platform.setProperty('cache-on-disk', 'yes');
        // We don't strictly need demuxer-cache-dir if we want to use OS temp, 
        // but it's safer to let MPV handle it.
      } else {
        platform.setProperty('cache-on-disk', 'no');
      }

      // --- Live Edge & Reconnection ---
      // Fixes ffurl_read errors by allowing MPV to handle reconnects
      // and ensuring the stream starts near the live edge.
      platform.setProperty('demuxer-lavf-o', 'live_start_index=-3');
      platform.setProperty('http-reconnect', 'yes');
      platform.setProperty('tls-verify', 'no'); // Ensures smoother handshake on some CDNs
      
      // Force seekable stream to avoid "Cannot seek" errors during DVR use
      platform.setProperty('force-seekable', 'yes');

      // --- Performance ---
      platform.setProperty('prefetch-playlist', 'yes');

      // --- Cache ---
      platform.setProperty('cache', 'yes');
      // allow more time for initial buffering
      platform.setProperty('demuxer-readahead-secs', '10');
      // cache-secs: how many seconds to keep in RAM/disk
      platform.setProperty('cache-secs', '3600'); 
    } catch (_) {
      // Ignore — some platforms don't expose mpv properties directly.
    }
  }
}
