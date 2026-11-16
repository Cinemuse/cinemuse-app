import 'dart:developer' as developer;
import 'dart:io' as io;

import 'package:cinemuse_app/features/streaming/models/resolved_stream.dart';
import 'package:cinemuse_app/features/streaming/models/stream_candidate.dart';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Bundle containing initialized [Player] and [VideoController] instances.
class PlayerEngineBundle {
  final Player player;
  final VideoController controller;

  const PlayerEngineBundle({required this.player, required this.controller});
}

/// Encapsulates creation and low-level MPV engine configuration
/// for media playback across platforms.
class PlayerEngineConfigurator {
  const PlayerEngineConfigurator._();

  /// Creates and configures a [Player] and its associated [VideoController].
  ///
  /// [certificateBundlePath] is the file of trusted certificate authorities
  /// HTTPS streams are checked against (`CertificateBundleSource`).
  static PlayerEngineBundle createEngine({
    required String certificateBundlePath,
  }) {
    final player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
    );

    final controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        hwdec: hardwareDecoding(
          isAndroid: io.Platform.isAndroid,
          isLinux: io.Platform.isLinux,
        ),
        vo: io.Platform.isAndroid ? 'gpu' : null,
        enableHardwareAcceleration: true,
      ),
    );

    applyMpvOptimizations(player);
    _applyProperties(player, tlsProperties(certificateBundlePath));

    return PlayerEngineBundle(player: player, controller: controller);
  }

  /// The hardware decoders mpv tries, in order, before the processor. On
  /// Android, when the chip's direct mode doesn't start (it didn't on a Fire
  /// Stick), its copy mode comes next, so the chip still decodes.
  @visibleForTesting
  static String hardwareDecoding({
    required bool isAndroid,
    required bool isLinux,
  }) {
    if (isAndroid) return 'mediacodec,mediacodec-copy';
    return isLinux ? 'auto' : 'auto-safe';
  }

  /// mpv never checks HTTPS certificates unless told to (`tls-verify` is off
  /// by default), and its TLS library needs the trusted authorities as a file.
  @visibleForTesting
  static Map<String, String> tlsProperties(String certificateBundlePath) => {
    'tls-verify': 'yes',
    'tls-ca-file': certificateBundlePath,
  };

  /// FFmpeg's reconnect options (mpv has none of its own). A dropped
  /// connection picks up at the byte it stopped at; a server error (5xx) is
  /// retried for about 7 s before the source fails.
  static const String _reconnectOptions =
      'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,'
      'reconnect_on_http_error=5xx,reconnect_delay_max=4';

  /// The engine options [stream] opens with: no reconnect when its source
  /// turns it off ([StreamCandidate.reconnects]).
  @visibleForTesting
  static Map<String, String> streamProperties(ResolvedStream stream) => {
    'stream-lavf-o': stream.candidate.reconnects ? _reconnectOptions : '',
  };

  /// Opens [stream] in [player], at [start] when given. Every film, episode
  /// and trailer opens through here, so one stream's options never carry
  /// over to the next.
  ///
  /// mpv starts the file at [start] itself: a seek sent while the file still
  /// loads is dropped, which played a resumed episode from 0:00.
  static Future<void> openStream(
    Player player,
    ResolvedStream stream, {
    required bool play,
    Duration? start,
  }) async {
    try {
      final mpv = player.platform as dynamic;
      for (final MapEntry(:key, :value) in streamProperties(stream).entries) {
        await mpv.setProperty(key, value);
      }
    } catch (e, st) {
      developer.log(
        'Failed to set MPV properties',
        name: 'VideoPlayer.PlayerEngineConfigurator',
        error: e,
        stackTrace: st,
        level: 800,
      );
    }
    await player.open(
      Media(stream.url, httpHeaders: stream.headers, start: start),
      play: play,
    );
  }

  static void _applyProperties(Player player, Map<String, String> properties) {
    try {
      final mpv = player.platform as dynamic;
      for (final MapEntry(:key, :value) in properties.entries) {
        mpv.setProperty(key, value);
      }
    } catch (e, st) {
      developer.log(
        'Failed to set MPV properties',
        name: 'VideoPlayer.PlayerEngineConfigurator',
        error: e,
        stackTrace: st,
        level: 800,
      );
    }
  }

  /// Configures platform-specific MPV properties for caching, synchronization,
  /// hardware decoding, and subtitle blending.
  static void applyMpvOptimizations(Player player) {
    try {
      final mpv = player.platform as dynamic;

      // ── Hardware Decoding & Rendering ─────────────────────────────────────
      // vd-lavc-dr: Zero-copy direct rendering from decoder to GPU texture.
      // On Linux, use 'auto' to avoid stalls on non-accelerated codecs (e.g. HEVC).
      if (!io.Platform.isLinux) {
        mpv.setProperty('vd-lavc-dr', 'yes');
      } else {
        mpv.setProperty('vd-lavc-dr', 'auto');
        // Fast software decoding optimizations for low-power CPUs
        mpv.setProperty('vd-lavc-fast', 'yes');
        mpv.setProperty('vd-lavc-skiploopfilter', 'nonkey');
      }
      mpv.setProperty('vd-lavc-threads', '0'); // Auto-pick optimal thread count

      final isMobile = io.Platform.isAndroid;

      // ── Video Sync & Smoothness ───────────────────────────────────────────
      // display-resample: syncs to the monitor's refresh rate, eliminates judder.
      // We disable this on Linux/WSL and mobile platforms as it can cause crashes
      // or heavy frame pacing/decoding latency on mobile SoCs.
      if (!io.Platform.isLinux && !isMobile) {
        mpv.setProperty('video-sync', 'display-resample');

        // Interpolation to smooth out frame pacing (reduces judder on 24fps content).
        mpv.setProperty('interpolation', 'yes');
        mpv.setProperty('tscale', 'oversample');
      } else if (isMobile) {
        // Fast, battery-efficient audio sync for mobile
        mpv.setProperty('video-sync', 'audio');
      }

      // ── Network & Caching ─────────────────────────────────────────────────
      // Optimized cache settings: fast startup and immediate playback
      // without blocking on huge initial pre-read buffers.
      mpv.setProperty('cache', 'yes');
      mpv.setProperty('cache-pause-initial', 'no');
      mpv.setProperty('cache-pause-wait', '1');

      if (isMobile) {
        mpv.setProperty('cache-secs', '20');
        mpv.setProperty('demuxer-max-bytes', '32MiB');
        mpv.setProperty('demuxer-readahead-secs', '10');
        mpv.setProperty('demuxer-max-back-bytes', '10MiB');
      } else {
        mpv.setProperty('cache-secs', '60');
        mpv.setProperty('demuxer-max-bytes', '128MiB');
        mpv.setProperty('demuxer-readahead-secs', '20');
        mpv.setProperty('demuxer-max-back-bytes', '30MiB');
      }

      // ── Reconnection ──────────────────────────────────────────────────────
      // The default; [openStream] sets it again for each stream.
      mpv.setProperty('stream-lavf-o', _reconnectOptions);

      // ── Audio & Volume ────────────────────────────────────────────────────
      // Allow boosting volume up to 150% for quiet sources.
      mpv.setProperty('volume-max', '150');

      // Fallback strategies for unsupported audio codecs.
      mpv.setProperty('audio-fallback-to-null', 'yes');

      // Audio output on Linux
      if (io.Platform.isLinux) {
        mpv.setProperty('ao', 'pulse,alsa');
      }

      // --- Networking & Compatibility ---
      // Fixes "Refusing to load potentially unsafe URL" error
      mpv.setProperty('load-unsafe-playlists', 'yes');

      // --- Subtitle Rendering Fix for Windows d3d11va ---
      // With hardware decoding, video frames live on the GPU. MPV's subtitle compositor
      // normally blends subtitles *after* GPU output, which silently fails with d3d11va.
      // 'blend-subtitles: video' forces compositing at decode time (before hardware upload).
      // Only set on Windows: on Linux OpenGL/EGL this forces heavy CPU compositing.
      if (io.Platform.isWindows) {
        mpv.setProperty('blend-subtitles', 'video');
      }
    } catch (e, st) {
      developer.log(
        'Failed to set MPV properties',
        name: 'VideoPlayer.PlayerEngineConfigurator',
        error: e,
        stackTrace: st,
        level: 800,
      );
    }
  }

  /// Configures subtitle delay in seconds via MPV property.
  static void setSubtitleDelay(Player player, double delaySeconds) {
    try {
      final mpv = player.platform as dynamic;
      mpv.setProperty('sub-delay', delaySeconds.toString());
    } catch (e, st) {
      developer.log(
        'Failed to set sub-delay',
        name: 'VideoPlayer.PlayerEngineConfigurator',
        error: e,
        stackTrace: st,
        level: 800,
      );
    }
  }
}
