import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Centralized platform information utility.
/// Identifies operating systems and specialized display environments (TV, desktop, mobile).
class PlatformInfo {
  static const MethodChannel _channel = MethodChannel('com.cinemuse/platform');
  static bool _isTV = false;
  static bool? _isTvOverrideForTesting;

  /// Call this during app initialization in [main].
  static Future<void> initialize() async {
    if (kIsWeb) return;

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

  /// Whether running on traditional desktop platforms (Windows, Linux, macOS).
  static bool get isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  /// Whether running on standard mobile platforms (Android Phone/Tablet, iOS).
  static bool get isMobile {
    if (kIsWeb) return true;
    return (Platform.isAndroid || Platform.isIOS) && !isTV;
  }
}
