import 'dart:developer' as developer;
import 'dart:io' as io;

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
  static PlayerEngineBundle createEngine() {
    final player = Player(
      configuration: const PlayerConfiguration(logLevel: MPVLogLevel.warn),
    );

    final controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        hwdec: io.Platform.isAndroid
            ? 'mediacodec'
            : (io.Platform.isLinux ? 'auto' : 'auto-safe'),
        vo: io.Platform.isAndroid ? 'gpu' : null,
        enableHardwareAcceleration: true,
      ),
    );

    applyMpvOptimizations(player);

    return PlayerEngineBundle(player: player, controller: controller);
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

      final isMobile = io.Platform.isAndroid || io.Platform.isIOS;

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
      // Robust reconnection for handling timeouts after long pauses.
      mpv.setProperty('http-reconnect', 'yes');
      mpv.setProperty('reconnect-on-network-error', 'yes');
      mpv.setProperty('reconnect-on-http-error', 'all');

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
