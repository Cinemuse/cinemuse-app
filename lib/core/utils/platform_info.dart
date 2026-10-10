import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Detects Android TV / Fire Stick at startup. The UI is the same everywhere
/// (layout by width only); [isTV] is the hook for small TV-only tweaks.
class PlatformInfo {
  static const MethodChannel _channel = MethodChannel('com.cinemuse/platform');
  static bool _isTV = false;
  static bool? _isTvOverrideForTesting;

  /// Call this during app initialization in [main].
  static Future<void> initialize() async {
    if (Platform.isAndroid) {
      try {
        _isTV = await _channel.invokeMethod<bool>('isTV') ?? false;
      } on PlatformException catch (_) {
        _isTV = false;
      }
    }
  }

  /// Whether the host system is an Android TV / Fire Stick.
  static bool get isTV => _isTvOverrideForTesting ?? _isTV;

  /// Allows unit tests to simulate TV environments.
  @visibleForTesting
  static void setTvForTesting(bool? value) {
    _isTvOverrideForTesting = value;
  }

  /// Whether running on a desktop platform (Windows, Linux).
  /// Uses [defaultTargetPlatform] so widget tests can fake another platform.
  static bool get isDesktop =>
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;
}
