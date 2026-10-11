import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/streaming/models/stream_metadata.dart';

class LocalSettings {
  final SubtitleStyle subtitleStyle;
  final VideoResolution maxResolution;

  const LocalSettings({
    this.subtitleStyle = const SubtitleStyle(),
    this.maxResolution = VideoResolution.unknown,
  });

  LocalSettings copyWith({
    SubtitleStyle? subtitleStyle,
    VideoResolution? maxResolution,
  }) {
    return LocalSettings(
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
      maxResolution: maxResolution ?? this.maxResolution,
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
  // Before REV-85 the enum index was stored: reordering the enum would
  // silently change the user's choice. Read once, then deleted.
  static const _keyOldMaxResolutionIndex = 'max_resolution';

  // Set by any change, so a slow load can't overwrite it (REV-85).
  bool _isChangedBeforeLoad = false;

  @override
  LocalSettings build() {
    // After build: the load sets `state`, which build can't do.
    unawaited(Future.microtask(_load));
    return const LocalSettings();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_isChangedBeforeLoad) return;

    final fontSize = prefs.getDouble(_keyFontSize) ?? 24.0;
    final colorHex = prefs.getString(_keyColor) ?? '#FFFFFFFF';
    final bgColorHex = prefs.getString(_keyBgColor) ?? '#00000000';
    final position = prefs.getDouble(_keyPosition) ?? 0.05;

    state = LocalSettings(
      subtitleStyle: SubtitleStyle(
        fontSize: fontSize,
        color: SubtitleStyle.hexToColor(colorHex),
        backgroundColor: SubtitleStyle.hexToColor(bgColorHex),
        verticalPosition: position,
      ),
      maxResolution: await _loadMaxResolution(prefs),
    );
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
}

// Lives for the whole session: the player and the resolver read it.
final localSettingsProvider =
    NotifierProvider<LocalSettingsNotifier, LocalSettings>(
      LocalSettingsNotifier.new,
    );
