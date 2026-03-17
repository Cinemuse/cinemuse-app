import 'dart:async';
import 'package:flutter/foundation.dart';
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
  Timer? _stallTimer;
  StreamSubscription? _bufferingSub;

  LiveTvSourceHandler(this._player);

  void dispose() {
    _stallTimer?.cancel();
    _bufferingSub?.cancel();
  }

  Future<LiveTvInitializationResult> initialize(
    Channel channel, 
    UserSettings settings, {
    VoidCallback? onStall,
  }) async {
    final url = channel.url;
    final isPremium = url.contains('.ts') || url.contains('extension=ts') || url.contains('live.php?mac=');

    // 1. Optimize Player properties for Live TV
    _optimizeForLiveStreaming(settings, isPremium);

    // 2. Prepare headers
    final headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:83.0) Gecko/20100101 Firefox/83.0',
      'Accept': '*/*',
      if (isPremium) 'Referer': 'https://tilescale.com/',
    };

    // 3. Open the stream with explicit headers
    _player.open(Media(url, httpHeaders: headers), play: true);

    // 4. Start Stall Watchdog
    final stallDuration = isPremium ? const Duration(seconds: 7) : const Duration(seconds: 15);

    _bufferingSub?.cancel();
    _stallTimer?.cancel();
    _bufferingSub = _player.stream.buffering.listen((isBuffering) {
      if (isBuffering) {
        _stallTimer ??= Timer(stallDuration, () {
          debugPrint('LiveTvSourceHandler: Stream stall detected (${stallDuration.inSeconds}s buffering).');
          if (onStall != null) {
            onStall();
          } else {
            // Fallback for when no callback is provided
            _player.open(Media('error://stall'), play: false); 
          }
        });
      } else {
        _stallTimer?.cancel();
        _stallTimer = null;
      }
    });

    // 5. Seek to the live edge only for HLS (where DVR is common). 
    // Raw TS streams often have broken durations and seeking causes stalls.
    if (!isPremium) {
      _seekToLiveEdge();
    }

    // 6. Create ResolvedStream
    final candidate = StreamCandidate(
      title: channel.name,
      infoHash: url,
      provider: 'Live TV',
      magnet: url,
      metadata: StreamMetadata.empty(),
    );

    final resolvedStream = ResolvedStream(
      url: url,
      provider: 'Live TV',
      candidate: candidate,
      headers: headers,
    );

    return LiveTvInitializationResult(
      resolvedStream: resolvedStream,
      title: channel.name,
    );
  }

  /// Seeks to the live edge (duration - 5s) as soon as the DVR window
  /// duration is known. For pure-live streams with no DVR this is a no-op.
  void _seekToLiveEdge() {
    _player.stream.duration
        .firstWhere((d) => d > const Duration(seconds: 30))
        .timeout(const Duration(seconds: 5))
        .then((duration) {
          final target = duration - const Duration(seconds: 5);
          if (target > Duration.zero) {
            _player.seek(target);
          }
        })
        .catchError((_) {
          // Stream has no DVR window or didn't expose duration
        });
  }

  void _optimizeForLiveStreaming(UserSettings settings, bool isPremium) {
    try {
      final platform = _player.platform as dynamic;

      // 1. DVR Window & Cache size
      final bufferBytes = settings.liveTvBufferSize * 1024 * 1024;
      final forwardBuffer = (bufferBytes * 0.1).clamp(100 * 1024 * 1024, bufferBytes).toInt();
      final backBuffer = (bufferBytes - forwardBuffer).clamp(0, bufferBytes).toInt();

      platform.setProperty('demuxer-max-bytes', forwardBuffer.toString());
      platform.setProperty('demuxer-max-back-bytes', backBuffer.toString());

      // 2. Disk Caching
      platform.setProperty('cache-on-disk', settings.enableLiveTvDiskCache ? 'yes' : 'no');

      // 3. Conditional Format & Reconnection
      if (isPremium) {
        // MPEG-TS specific optimizations
        platform.setProperty('ffmpeg-format', 'mpegts');
        platform.setProperty('demuxer-lavf-o', 'analyze_max_duration=500000,probesize=500000,live_start_index=-3,reconnect_streamed=1,reconnect_delay_max=1');
        platform.setProperty('force-seekable', 'no'); // Prevents stalls on raw TS
      } else {
        platform.setProperty('demuxer-lavf-o', 'live_start_index=-3');
        platform.setProperty('force-seekable', 'yes');
      }

      platform.setProperty('http-reconnect', 'yes');
      platform.setProperty('reconnect-on-network-error', 'yes');
      platform.setProperty('reconnect-on-http-error', 'all');
      platform.setProperty('tls-verify', 'no');
      platform.setProperty('prefetch-playlist', 'yes');
      platform.setProperty('cache', 'yes');
      platform.setProperty('cache-pause', 'yes'); 
      platform.setProperty('cache-initial', '0'); 
      platform.setProperty('cache-pause-initial', 'no'); 
      platform.setProperty('demuxer-readahead-secs', isPremium ? '25' : '15');
      platform.setProperty('cache-secs', '3600'); 
      platform.setProperty('load-unsafe-playlists', 'yes');
      
      // We set headers in the Media constructor, but keeping these as fallback
      platform.setProperty('user-agent', 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:83.0) Gecko/20100101 Firefox/83.0');
    } catch (_) {
    }
  }
}
