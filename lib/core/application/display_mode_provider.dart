import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Supported display modes for Cinemuse.
enum DisplayMode {
  /// Standard UI layout suited for touch screens and mouse/keyboard desktop usage.
  standard,

  /// 10-foot Big Picture UI designed for TV screens, gamepads, and D-Pad remotes.
  bigPicture,
}

class DisplayModeNotifier extends StateNotifier<DisplayMode> {
  static const String _prefKey = 'display_mode';

  DisplayModeNotifier() : super(_initialMode) {
    _loadPreference();
  }

  static DisplayMode get _initialMode {
    return DisplayMode.bigPicture;
  }

  Future<void> _loadPreference() async {
    // If we're on a physical TV device, enforce bigPicture by default unless explicitly configured.
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        state = saved == DisplayMode.bigPicture.name
            ? DisplayMode.bigPicture
            : DisplayMode.standard;
      }
    } catch (e, s) {
      developer.log(
        'Failed to load display mode preference, keeping default',
        name: 'DisplayModeNotifier',
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> setMode(DisplayMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.name);
    } catch (e, s) {
      developer.log(
        'Failed to persist display mode preference: ${mode.name}',
        name: 'DisplayModeNotifier',
        error: e,
        stackTrace: s,
      );
    }
  }

  Future<void> toggleMode() async {
    final next = state == DisplayMode.standard
        ? DisplayMode.bigPicture
        : DisplayMode.standard;
    await setMode(next);
  }
}

final displayModeProvider =
    StateNotifierProvider<DisplayModeNotifier, DisplayMode>((ref) {
  return DisplayModeNotifier();
});

final isBigPictureProvider = Provider<bool>((ref) {
  return ref.watch(displayModeProvider) == DisplayMode.bigPicture;
});
