import 'dart:async';
import 'dart:io' show Platform;

import 'package:cinemuse_app/core/services/system/free_memory_reader.dart';
import 'package:cinemuse_app/core/utils/app_logger.dart';
import 'package:cinemuse_app/core/utils/platform_info.dart';
import 'package:flutter/foundation.dart';
import 'package:cinemuse_app/features/live_tv/data/live_link_resolver.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_address.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/features/video_player/application/helpers/live_buffer_size.dart';
import 'package:media_kit/media_kit.dart';

class LiveTvInitializationResult {
  final ResolvedStream resolvedStream;

  LiveTvInitializationResult({required this.resolvedStream});
}

class LiveTvSourceHandler {
  static const _logTag = 'LiveTvSourceHandler';

  final Player _player;
  final LiveLinkResolver _resolver;
  final Future<int?> Function() _readFreeMemory;
  final LiveDevice _device;
  Timer? _stallTimer;
  StreamSubscription? _bufferingSub;
  bool _isDisposed = false;

  LiveTvSourceHandler(
    this._player, {
    LiveLinkResolver? resolver,
    Future<int?> Function()? readFreeMemory,
    LiveDevice? device,
  }) : _resolver = resolver ?? LiveLinkResolver(),
       _readFreeMemory = readFreeMemory ?? FreeMemoryReader.read,
       _device = device ?? _thisDevice();

  static LiveDevice _thisDevice() {
    if (PlatformInfo.isTV) return LiveDevice.tv;
    return Platform.isAndroid ? LiveDevice.phone : LiveDevice.computer;
  }

  void dispose() {
    _isDisposed = true;
    _stallTimer?.cancel();
    _bufferingSub?.cancel();
  }

  Future<LiveTvInitializationResult?> initialize(
    Channel channel,
    UserSettings settings, {
    VoidCallback? onStall,
    String videoTrack = 'auto',
  }) async {
    return _initializeStreamUrl(
      channel,
      channel.url,
      channel.link?.ask,
      channel.link?.headers ?? const {},
      'Live TV',
      settings,
      onStall: onStall,
      videoTrack: videoTrack,
    );
  }

  Future<LiveTvInitializationResult?> initializeWithLink(
    Channel channel,
    StreamLink link,
    UserSettings settings, {
    VoidCallback? onStall,
    String videoTrack = 'auto',
  }) async {
    return _initializeStreamUrl(
      channel,
      link.url,
      link.ask,
      link.headers,
      link.displayProvider,
      settings,
      onStall: onStall,
      videoTrack: videoTrack,
    );
  }

  Future<LiveTvInitializationResult?> _initializeStreamUrl(
    Channel channel,
    String rawUrl,
    String? ask,
    Map<String, String> playlistHeaders,
    String providerLabel,
    UserSettings settings, {
    VoidCallback? onStall,
    required String videoTrack,
  }) async {
    final url = await _resolver.resolve(rawUrl, ask);
    // Another channel was picked during the lookup: opening this one now
    // would play it under the new channel's name (REV-146).
    if (_isDisposed) return null;
    final freeMemory = await _readFreeMemory();
    if (_isDisposed) return null;
    final address = StreamAddress(url);
    final isRawTs = address.isRawTs;

    // 1. Optimize Player properties for Live TV. The channel's data rate is
    // only known once it plays, so it opens with the device's whole share.
    final rewindMinutes = settings.liveTvRewindMinutes;
    final openingSize = LiveBufferSize.forChannel(
      device: _device,
      rewindMinutes: rewindMinutes,
      freeMemoryBytes: freeMemory,
    );
    _optimizeForLiveStreaming(openingSize, isRawTs);

    final userAgent = address.isXtream || isRawTs
        ? 'VLC/3.0.18 LibVLC/3.0.18'
        : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

    // 2. Prepare headers: the playlist's own win over the app's guesses.
    final headers = {
      'User-Agent': userAgent,
      'Accept': '*/*',
      ...playlistHeaders,
    };

    // 3. Open the stream with explicit headers, on the picture size wanted
    await _selectVideoTrack(videoTrack);
    // Not awaited: the stall watchdog below handles a stream that never starts.
    unawaited(_player.open(Media(url, httpHeaders: headers), play: true));

    // 4. Start Stall Watchdog
    final stallDuration = Duration(seconds: isRawTs ? 7 : 15);

    // The old listener only has to stop; a new one is attached right after.
    unawaited(_bufferingSub?.cancel());
    _stallTimer?.cancel();
    _bufferingSub = _player.stream.buffering.listen((isBuffering) {
      if (isBuffering) {
        _stallTimer ??= Timer(stallDuration, () {
          AppLogger.info(
            _logTag,
            'Stream stall detected (${stallDuration.inSeconds}s buffering).',
          );
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
    if (!isRawTs) _seekToLiveEdge();
    _fitBufferToChannel(openingSize, rewindMinutes, freeMemory);

    // 6. Create ResolvedStream
    final candidate = StreamCandidate(
      kind: StreamSourceKind.live,
      title: channel.name,
      url: url,
      provider: providerLabel,
      metadata: StreamMetadata.empty(),
      headers: headers,
    );

    final resolvedStream = ResolvedStream(
      url: url,
      provider: providerLabel,
      candidate: candidate,
      headers: headers,
    );

    return LiveTvInitializationResult(resolvedStream: resolvedStream);
  }

  /// Seeks to the live edge (duration - 5s) as soon as the DVR window
  /// duration is known. For pure-live streams with no DVR this is a no-op.
  void _seekToLiveEdge() {
    _player.stream.duration
        .firstWhere((d) => d > const Duration(seconds: 30))
        .timeout(const Duration(seconds: 5))
        .then((duration) {
          final target = duration - const Duration(seconds: 5);
          if (target > Duration.zero) _player.seek(target);
        })
        .catchError((Object e) {
          AppLogger.debug(_logTag, 'Live edge seek: no DVR window ($e)');
        });
  }

  /// Once the picture shows, the channel's data rate is known: the buffer
  /// shrinks to what [rewindMinutes] needs. A channel that never says its
  /// rate (or a radio, with no picture) keeps [opened].
  void _fitBufferToChannel(
    LiveBufferSize opened,
    int rewindMinutes,
    int? freeMemory,
  ) {
    _player.stream.width
        .firstWhere((width) => (width ?? 0) > 0)
        .timeout(const Duration(seconds: 30))
        .then((_) => _readBitrate())
        .then((bitsPerSecond) {
          if (_isDisposed || bitsPerSecond == null) return;
          final fitted = LiveBufferSize.forChannel(
            device: _device,
            rewindMinutes: rewindMinutes,
            freeMemoryBytes: freeMemory,
            bitsPerSecond: bitsPerSecond,
          );
          if (fitted != opened) _applyBufferSize(_player.platform, fitted);
        })
        .catchError((Object e) {
          AppLogger.debug(_logTag, 'Buffer kept at its opening size ($e)');
        });
  }

  /// The rate the stream's list declares for the picture size playing, or
  /// failing that the one the engine measured; null when neither is known.
  Future<int?> _readBitrate() async {
    final platform = _player.platform as dynamic;
    for (final property in const [
      'current-tracks/video/hls-bitrate',
      'current-tracks/video/demux-bitrate',
    ]) {
      final value = num.tryParse(
        await platform.getProperty(property) as String,
      );
      if (value != null && value > 0) return value.toInt();
    }
    return null;
  }

  static void _applyBufferSize(Object? platform, LiveBufferSize size) {
    final native = platform as dynamic;
    native.setProperty('demuxer-max-bytes', size.aheadBytes.toString());
    native.setProperty('demuxer-max-back-bytes', size.rewindBytes.toString());
  }

  /// mpv keeps `vid` for the next file, so every open sets it: [track] is a
  /// track id, or "auto" for mpv's own pick (the biggest size).
  Future<void> _selectVideoTrack(String track) async {
    try {
      final platform = _player.platform as dynamic;
      await platform.setProperty('vid', track);
    } catch (e, s) {
      // The stream still opens, on mpv's own pick.
      AppLogger.warn(_logTag, 'Video track not set', error: e, stackTrace: s);
    }
  }

  void _optimizeForLiveStreaming(LiveBufferSize bufferSize, bool isRawTs) {
    try {
      final platform = _player.platform as dynamic;

      // 1. Buffer size. Always in memory: the engine's disk cache file only
      // grows while a channel plays, its size limits apply to its index only.
      _applyBufferSize(platform, bufferSize);

      // 2. Conditional Format & Reconnection
      if (isRawTs) {
        platform.setProperty(
          'force-seekable',
          'no',
        ); // Prevents stalls on raw TS
      } else {
        // http_seekable=0: each chunk is downloaded in one go. Fetched in
        // pieces, Rai's chunks came back with a broken end, so the sound and
        // picture stuttered every 10 seconds.
        platform.setProperty(
          'demuxer-lavf-o',
          'live_start_index=-3,http_seekable=0',
        );
        platform.setProperty('force-seekable', 'yes');
      }

      // FFmpeg's reconnect options (mpv has none of its own); without
      // `reconnect=1` the others do nothing. Short delays: a dead link is
      // left to the stall watchdog and the next link.
      platform.setProperty(
        'stream-lavf-o',
        'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,'
            'reconnect_on_http_error=5xx,reconnect_delay_max=2',
      );
      platform.setProperty('prefetch-playlist', 'yes');
      platform.setProperty('cache', 'yes');
      platform.setProperty('cache-pause', 'yes');
      platform.setProperty('cache-pause-initial', 'no');
      platform.setProperty('demuxer-readahead-secs', isRawTs ? '25' : '15');
      platform.setProperty('cache-secs', '3600');
      platform.setProperty('load-unsafe-playlists', 'yes');

      // We set headers in the Media constructor, but keeping these as fallback
      platform.setProperty(
        'user-agent',
        isRawTs
            ? 'VLC/3.0.18 LibVLC/3.0.18'
            : 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:83.0) Gecko/20100101 Firefox/83.0',
      );
    } catch (e, s) {
      // Playback still starts, with mpv's defaults.
      AppLogger.warn(
        _logTag,
        'Player properties not set',
        error: e,
        stackTrace: s,
      );
    }
  }
}
