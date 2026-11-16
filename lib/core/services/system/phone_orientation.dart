import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:cinemuse_app/core/utils/platform_info.dart';

/// On a phone the app stays upright, because its screens have no sideways
/// layout yet. While a video player is open the phone turns freely, and the
/// player's full screen turns the video sideways. TVs, tablets and PCs are
/// left alone.
class PhoneOrientation {
  const PhoneOrientation._();

  /// A screen whose shorter side is under this many points is a phone.
  static const _phoneShortestSide = 600.0;

  static bool _isPhone = false;
  static int _openPlayers = 0;

  /// This device is a phone; known from the first frame on.
  static bool get isPhone => _isPhone;

  static bool isPhoneScreen({
    required bool isAndroid,
    required bool isTV,
    required Size screen,
  }) => isAndroid && !isTV && screen.shortestSide < _phoneShortestSide;

  /// Called once at start. Waits for the first frame that knows the
  /// screen's size, after [PlatformInfo.initialize].
  static void initializeWhenSized() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final view = WidgetsBinding.instance.platformDispatcher.implicitView;
      if (view == null || view.physicalSize.isEmpty) {
        initializeWhenSized();
        return;
      }
      _isPhone = isPhoneScreen(
        isAndroid: defaultTargetPlatform == TargetPlatform.android,
        isTV: PlatformInfo.isTV,
        screen: view.physicalSize / view.devicePixelRatio,
      );
      // A frame callback can't wait; the turn needs nothing after it.
      unawaited(_apply());
    });
  }

  /// A video player screen opened: the phone may turn.
  static Future<void> playerOpened() {
    _openPlayers++;
    return _apply();
  }

  /// A video player screen closed: upright again once none is open.
  static Future<void> playerClosed() {
    if (_openPlayers > 0) _openPlayers--;
    return _apply();
  }

  /// The player's full screen ended. Replaces media_kit's own, which would
  /// let the phone turn everywhere.
  static Future<void> exitFullscreen() async {
    if (!_isPhone) return defaultExitNativeFullscreen();
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    await _apply();
  }

  static Future<void> _apply() async {
    if (!_isPhone) return;
    await SystemChrome.setPreferredOrientations(
      _openPlayers > 0 ? const [] : const [DeviceOrientation.portraitUp],
    );
  }

  @visibleForTesting
  static void setUpForTesting({required bool isPhone}) {
    _isPhone = isPhone;
    _openPlayers = 0;
  }
}
