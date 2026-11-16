import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/core/utils/platform_info.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';

class LocalSettings {
  final SubtitleStyle subtitleStyle;
  final VideoResolution maxResolution;

  /// How long the Undo message stays after a removal; zero is Off.
  final Duration undoTime;

  /// How big the whole app is drawn, in percent (see [screenPercents]).
  final int screenPercent;

  /// The app opens in full screen (Windows and Linux).
  final bool startFullScreen;

  const LocalSettings({
    this.subtitleStyle = const SubtitleStyle(),
    this.maxResolution = VideoResolution.unknown,
    this.undoTime = AppSnackBar.defaultUndoDuration,
    this.screenPercent = 100,
    this.startFullScreen = false,
  });

  /// The Screen size choices.
  static const screenPercents = [67, 75, 80, 90, 100, 110, 125, 150];

  /// A TV starts at 2/3: Android counts it as only 960 wide, so the app's
  /// sizes come out twice as big as on a computer.
  static int get defaultScreenPercent => PlatformInfo.isTV ? 67 : 100;

  LocalSettings copyWith({
    SubtitleStyle? subtitleStyle,
    VideoResolution? maxResolution,
    Duration? undoTime,
    int? screenPercent,
    bool? startFullScreen,
  }) {
    return LocalSettings(
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      maxResolution: maxResolution ?? this.maxResolution,
      undoTime: undoTime ?? this.undoTime,
      screenPercent: screenPercent ?? this.screenPercent,
      startFullScreen: startFullScreen ?? this.startFullScreen,
    );
  }
}

/// Settings kept on this device only (SharedPreferences).
class LocalSettingsNotifier extends Notifier<LocalSettings> {
  static const _keyFontSize = 'subtitle_font_size';
  static const _keyColor = 'subtitle_color';
  static const _keyBgColor = 'subtitle_bg_color';
  static const _keyPosition = 'subtitle_position';
  static const _keyMaxResolution = 'max_resolution_name';
  static const _keyUndoSeconds = 'undo_seconds';
  static const _keyScreenPercent = 'screen_percent';
  static const _keyStartFullScreen = 'start_full_screen';
  // Before REV-85 the enum index was stored: reordering the enum would
  // silently change the user's choice. Read once, then deleted.
  static const _keyOldMaxResolutionIndex = 'max_resolution';

  // Set by any change, so a slow load can't overwrite it (REV-85).
  bool _isChangedBeforeLoad = false;

  @override
  LocalSettings build() {
    // After build: the load sets `state`, which build can't do.
    unawaited(Future.microtask(_load));
    return LocalSettings(screenPercent: LocalSettings.defaultScreenPercent);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isChangedBeforeLoad) return;

    final fontSize = prefs.getDouble(_keyFontSize) ?? 24.0;
    final colorHex = prefs.getString(_keyColor) ?? '#FFFFFFFF';
    final bgColorHex = prefs.getString(_keyBgColor) ?? '#00000000';
    final position = prefs.getDouble(_keyPosition) ?? 0.05;
    final maxResolution = await _loadMaxResolution(prefs);
    final undoSeconds = prefs.getInt(_keyUndoSeconds);
    final screenPercent = prefs.getInt(_keyScreenPercent);
    final startFullScreen = prefs.getBool(_keyStartFullScreen) ?? false;
    if (!ref.mounted || _isChangedBeforeLoad) return;

    state = LocalSettings(
      subtitleStyle: SubtitleStyle(
        fontSize: fontSize,
        color: SubtitleStyle.hexToColor(colorHex),
        backgroundColor: SubtitleStyle.hexToColor(bgColorHex),
        verticalPosition: position,
      ),
      maxResolution: maxResolution,
      undoTime: undoSeconds == null
          ? AppSnackBar.defaultUndoDuration
          : Duration(seconds: undoSeconds),
      screenPercent: LocalSettings.screenPercents.contains(screenPercent)
          ? screenPercent!
          : LocalSettings.defaultScreenPercent,
      startFullScreen: startFullScreen,
    );
  }

  /// Read once at start, before the window shows.
  static Future<bool> readStartFullScreen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyStartFullScreen) ?? false;
  }

  Future<VideoResolution> _loadMaxResolution(SharedPreferences prefs) async {
    final name = prefs.getString(_keyMaxResolution);
    if (name != null) {
      return VideoResolution.values.asNameMap()[name] ??
          VideoResolution.unknown;
    }

    final oldIndex = prefs.getInt(_keyOldMaxResolutionIndex);
    if (oldIndex == null) return VideoResolution.unknown;
    // The enum order the index was saved with (REV-85).
    const oldOrder = [
      VideoResolution.r2160p,
      VideoResolution.r1440p,
      VideoResolution.r1080p,
      VideoResolution.r720p,
      VideoResolution.r480p,
      VideoResolution.unknown,
    ];
    final resolution = oldIndex >= 0 && oldIndex < oldOrder.length
        ? oldOrder[oldIndex]
        : VideoResolution.unknown;
    await prefs.setString(_keyMaxResolution, resolution.name);
    await prefs.remove(_keyOldMaxResolutionIndex);
    return resolution;
  }

  /// Shows [style] at once without saving it (a slider being dragged).
  void previewSubtitleStyle(SubtitleStyle style) {
    _isChangedBeforeLoad = true;
    state = state.copyWith(subtitleStyle: style);
  }

  /// Shows and saves [style].
  Future<void> updateSubtitleStyle(SubtitleStyle style) async {
    previewSubtitleStyle(style);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, style.fontSize);
    await prefs.setString(_keyColor, SubtitleStyle.colorToHex(style.color));
    await prefs.setString(
      _keyBgColor,
      SubtitleStyle.colorToHex(style.backgroundColor),
    );
    await prefs.setDouble(_keyPosition, style.verticalPosition);
  }

  Future<void> updateMaxResolution(VideoResolution resolution) async {
    _isChangedBeforeLoad = true;
    state = state.copyWith(maxResolution: resolution);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMaxResolution, resolution.name);
  }

  Future<void> updateUndoTime(Duration time) async {
    _isChangedBeforeLoad = true;
    state = state.copyWith(undoTime: time);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyUndoSeconds, time.inSeconds);
  }

  Future<void> updateScreenPercent(int percent) async {
    _isChangedBeforeLoad = true;
    state = state.copyWith(screenPercent: percent);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyScreenPercent, percent);
  }

  Future<void> updateStartFullScreen(bool on) async {
    _isChangedBeforeLoad = true;
    state = state.copyWith(startFullScreen: on);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyStartFullScreen, on);
  }
}

// Lives for the whole session: the player and the resolver read it.
final localSettingsProvider =
    NotifierProvider<LocalSettingsNotifier, LocalSettings>(
      LocalSettingsNotifier.new,
    );
