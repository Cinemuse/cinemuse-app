import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_color_picker.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_style_slider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class SubtitleAppearanceForm extends StatelessWidget {
  final SubtitleStyle style;

  /// A slider is moving: show it, don't save yet.
  final ValueChanged<SubtitleStyle> onChanged;

  /// A change is final (drag ended, colour picked): save it (REV-85).
  final ValueChanged<SubtitleStyle> onChangeEnd;

  const SubtitleAppearanceForm({
    super.key,
    required this.style,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SubtitlePreview(style: style, label: l10n.playerAppearanceSampleText),
        const SizedBox(height: 16),
        SubtitleStyleSlider(
          kind: SubtitleStyleSliderKind.fontSize,
          style: style,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
        SubtitleColorPicker(
          selectedColor: style.color,
          onColorSelected: (color) => onChangeEnd(style.copyWith(color: color)),
        ),
        SubtitleStyleSlider(
          kind: SubtitleStyleSliderKind.background,
          style: style,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
        SubtitleStyleSlider(
          kind: SubtitleStyleSliderKind.position,
          style: style,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}

class _SubtitlePreview extends StatelessWidget {
  final SubtitleStyle style;
  final String label;

  const _SubtitlePreview({required this.style, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        // A local gradient, not a downloaded photo: works offline and
        // calls no third-party site (REV-85).
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.accent.withValues(alpha: 0.25), AppTheme.primary],
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: style.backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: style.color,
            fontSize: style.fontSize,
            fontWeight: FontWeight.w500,
            shadows: [
              if (style.backgroundColor == Colors.transparent)
                const Shadow(
                  blurRadius: 4.0,
                  color: Colors.black,
                  offset: Offset(0, 1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
