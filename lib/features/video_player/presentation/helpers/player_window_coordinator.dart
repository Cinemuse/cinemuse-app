import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:ui' show Rect;
import 'package:flutter/foundation.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

/// Coordinates fullscreen transitions, desktop window positioning, and maximizing/unmaximizing
/// across Windows, Linux, and other platforms without polluting UI widgets.
class PlayerWindowCoordinator {
  const PlayerWindowCoordinator._();

  static bool _wasMaximizedBeforeFullscreen = false;
  static Rect? _previousBounds;

  /// Safely queries the underlying [VideoState] fullscreen status.
  static bool isFullscreenSafe(VideoState videoState) {
    try {
      return videoState.isFullscreen();
    } catch (e, st) {
      developer.log(
        'Failed to query fullscreen state',
        name: 'VideoPlayer.PlayerWindowCoordinator',
        error: e,
        stackTrace: st,
        level: 500,
      );
      return false;
    }
  }

  /// Toggles fullscreen, preserving and restoring previous desktop window bounds.
  ///
  /// Returns the resulting fullscreen state (`true` if fullscreen, `false` otherwise).
  static Future<bool> toggleFullscreen(VideoState videoState) async {
    final isCurrentlyFull = isFullscreenSafe(videoState);

    if (isCurrentlyFull) {
      developer.log(
        'Exiting fullscreen. wasMaximized: $_wasMaximizedBeforeFullscreen, prevBounds: $_previousBounds',
        name: 'VideoPlayer.PlayerWindowCoordinator',
      );
      await videoState.exitFullscreen();
      if (Platform.isWindows || Platform.isLinux) {
        if (!_wasMaximizedBeforeFullscreen) {
          await windowManager.unmaximize();
          if (_previousBounds != null) {
            await windowManager.setBounds(_previousBounds!);
          }
        } else {
          developer.log(
            'Restoring maximized state',
            name: 'VideoPlayer.PlayerWindowCoordinator',
          );
          await windowManager.maximize();
        }
      }
      return false;
    } else {
      if (Platform.isWindows || Platform.isLinux) {
        _wasMaximizedBeforeFullscreen = await windowManager.isMaximized();
        developer.log(
          'Entering fullscreen. initiallyMaximized: $_wasMaximizedBeforeFullscreen',
          name: 'VideoPlayer.PlayerWindowCoordinator',
        );
        if (!_wasMaximizedBeforeFullscreen) {
          _previousBounds = await windowManager.getBounds();
          developer.log(
            'Saved bounds: $_previousBounds. Maximizing to trick WM.',
            name: 'VideoPlayer.PlayerWindowCoordinator',
          );
          await windowManager.maximize();
        }
      }
      await videoState.enterFullscreen();
      return true;
    }
  }

  /// Handles back press, ensuring fullscreen is cleanly exited on desktop before invoking [onBackPressed].
  static Future<void> handleBack({
    required VideoState videoState,
    VoidCallback? onBackPressed,
  }) async {
    if (isFullscreenSafe(videoState)) {
      developer.log(
        'handleBack: Exiting fullscreen. wasMaximized: $_wasMaximizedBeforeFullscreen, prevBounds: $_previousBounds',
        name: 'VideoPlayer.PlayerWindowCoordinator',
      );
      await videoState.exitFullscreen();
      if (Platform.isWindows || Platform.isLinux) {
        if (!_wasMaximizedBeforeFullscreen) {
          await windowManager.unmaximize();
          if (_previousBounds != null) {
            await windowManager.setBounds(_previousBounds!);
          }
        } else {
          developer.log(
            'handleBack: Restoring maximized state',
            name: 'VideoPlayer.PlayerWindowCoordinator',
          );
          await windowManager.maximize();
        }
      }
    }
    onBackPressed?.call();
  }
}
