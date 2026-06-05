import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/core/services/streaming/models/stream_metadata.dart';

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

class LocalSettingsNotifier extends StateNotifier<LocalSettings> {
  LocalSettingsNotifier() : super(const LocalSettings()) {
    _load();
  }

  static const _keyFontSize = 'subtitle_font_size';
  static const _keyColor = 'subtitle_color';
  static const _keyBgColor = 'subtitle_bg_color';
  static const _keyPosition = 'subtitle_position';
  static const _keyMaxResolution = 'max_resolution';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();

    final fontSize = prefs.getDouble(_keyFontSize) ?? 24.0;
    final colorHex = prefs.getString(_keyColor) ?? '#FFFFFFFF';
    final bgColorHex = prefs.getString(_keyBgColor) ?? '#00000000';
    final position = prefs.getDouble(_keyPosition) ?? 0.05;

    final maxResIndex = prefs.getInt(_keyMaxResolution);
    final maxResolution = maxResIndex != null
        ? VideoResolution.values.firstWhere(
            (e) => e.index == maxResIndex,
            orElse: () => VideoResolution.unknown,
          )
        : VideoResolution.unknown;

    state = LocalSettings(
      subtitleStyle: SubtitleStyle(
        fontSize: fontSize,
        color: SubtitleStyle.hexToColor(colorHex),
        backgroundColor: SubtitleStyle.hexToColor(bgColorHex),
        verticalPosition: position,
      ),
      maxResolution: maxResolution,
    );
  }

  Future<void> updateSubtitleStyle(SubtitleStyle style) async {
    state = state.copyWith(subtitleStyle: style);

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
    state = state.copyWith(maxResolution: resolution);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyMaxResolution, resolution.index);
  }

  Future<void> resetToDefaults() async {
    const defaultStyle = SubtitleStyle();
    await updateSubtitleStyle(defaultStyle);
    await updateMaxResolution(VideoResolution.unknown);
  }
}

final localSettingsProvider =
    StateNotifierProvider<LocalSettingsNotifier, LocalSettings>((ref) {
      return LocalSettingsNotifier();
    });
