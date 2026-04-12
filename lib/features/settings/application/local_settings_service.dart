import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';

class LocalSettings {
  final SubtitleStyle subtitleStyle;

  const LocalSettings({
    this.subtitleStyle = const SubtitleStyle(),
  });

  LocalSettings copyWith({
    SubtitleStyle? subtitleStyle,
  }) {
    return LocalSettings(
      subtitleStyle: subtitleStyle ?? this.subtitleStyle,
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

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    
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
    );
  }

  Future<void> updateSubtitleStyle(SubtitleStyle style) async {
    state = state.copyWith(subtitleStyle: style);
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyFontSize, style.fontSize);
    await prefs.setString(_keyColor, SubtitleStyle.colorToHex(style.color));
    await prefs.setString(_keyBgColor, SubtitleStyle.colorToHex(style.backgroundColor));
    await prefs.setDouble(_keyPosition, style.verticalPosition);
  }

  Future<void> resetToDefaults() async {
    const defaultStyle = SubtitleStyle();
    await updateSubtitleStyle(defaultStyle);
  }
}

final localSettingsProvider = StateNotifierProvider<LocalSettingsNotifier, LocalSettings>((ref) {
  return LocalSettingsNotifier();
});
