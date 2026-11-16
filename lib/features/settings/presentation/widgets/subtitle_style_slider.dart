import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_slider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

/// The subtitle settings set with a slider.
enum SubtitleStyleSliderKind {
  fontSize(min: 12, max: 48),
  // 5% steps.
  position(min: 0, max: 1, divisions: 20),
  background(min: 0, max: 1);

  final double min;
  final double max;
  final int? divisions;

  const SubtitleStyleSliderKind({
    required this.min,
    required this.max,
    this.divisions,
  });

  String title(AppLocalizations l10n) => switch (this) {
    fontSize => l10n.playerAppearanceFontSize,
    position => l10n.playerAppearanceBottomPadding,
    background => l10n.playerAppearanceBackground,
  };

  double valueOf(SubtitleStyle style) => switch (this) {
    fontSize => style.fontSize,
    position => style.verticalPosition,
    background => style.backgroundColor.a.clamp(0.0, 1.0),
  };

  /// The value as shown next to the slider and in the player's menu.
  String valueLabel(double value) => switch (this) {
    fontSize => '${value.toInt()} px',
    position || background => '${(value * 100).toInt()}%',
  };

  SubtitleStyle apply(SubtitleStyle style, double value) => switch (this) {
    fontSize => style.copyWith(fontSize: value),
    position => style.copyWith(verticalPosition: value),
    background => style.copyWith(
      backgroundColor: Colors.black.withValues(alpha: value),
    ),
  };
}

/// One subtitle slider, the same in Settings → Subtitles and in the player's
/// subtitle panel (REV-308).
class SubtitleStyleSlider extends StatelessWidget {
  final SubtitleStyleSliderKind kind;
  final SubtitleStyle style;

  /// False where a title above already names the setting.
  final bool showLabel;

  /// The slider is moving: show it.
  final ValueChanged<SubtitleStyle> onChanged;

  /// The drag ended: save here, not in [onChanged].
  final ValueChanged<SubtitleStyle>? onChangeEnd;

  const SubtitleStyleSlider({
    super.key,
    required this.kind,
    required this.style,
    this.showLabel = true,
    required this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final value = kind.valueOf(style);
    final onEnd = onChangeEnd;
    final slider = SettingSlider(
      label: showLabel ? kind.title(l10n) : null,
      value: value,
      min: kind.min,
      max: kind.max,
      divisions: kind.divisions,
      valueLabelBuilder: kind.valueLabel,
      onChanged: (v) => onChanged(kind.apply(style, v)),
      onChangeEnd: onEnd == null ? null : (v) => onEnd(kind.apply(style, v)),
    );
    if (kind != SubtitleStyleSliderKind.position) return slider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        slider,
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AnchorLabel(
                label: l10n.playerAppearancePositionBottom,
                isSelected: value < 0.2,
              ),
              _AnchorLabel(
                label: l10n.playerAppearancePositionMiddle,
                isSelected: value > 0.4 && value < 0.6,
              ),
              _AnchorLabel(
                label: l10n.playerAppearancePositionTop,
                isSelected: value > 0.8,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnchorLabel extends StatelessWidget {
  final String label;
  final bool isSelected;

  const _AnchorLabel({required this.label, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: isSelected ? AppTheme.accent : AppTheme.textMuted.withAlpha(128),
        letterSpacing: 1.1,
      ),
    );
  }
}
