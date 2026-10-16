import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/setting_slider.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_text_colors.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

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
    SubtitleStyle withBackground(double alpha) => style.copyWith(
      backgroundColor: Colors.black.withAlpha((alpha * 255).round()),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SubtitlePreview(style: style, label: l10n.playerAppearanceSampleText),
        const SizedBox(height: 16),
        // Font Size
        SettingSlider(
          label: l10n.playerAppearanceFontSize,
          value: style.fontSize,
          min: 12.0,
          max: 48.0,
          onChanged: (val) => onChanged(style.copyWith(fontSize: val)),
          onChangeEnd: (val) => onChangeEnd(style.copyWith(fontSize: val)),
        ),

        // Text Color
        _ColorSelectorTile(
          label: l10n.playerAppearanceTextColor,
          selectedColor: style.color,
          colors: subtitleTextColors,
          onColorSelected: (color) => onChangeEnd(style.copyWith(color: color)),
        ),

        // Background Opacity
        SettingSlider(
          label: l10n.playerAppearanceBackground,
          value: style.backgroundColor.a.clamp(0.0, 1.0),
          min: 0.0,
          max: 1.0,
          valueLabelBuilder: (val) => '${(val * 100).toInt()}%',
          onChanged: (val) => onChanged(withBackground(val)),
          onChangeEnd: (val) => onChangeEnd(withBackground(val)),
        ),

        // Vertical Position
        _PositionSliderTile(
          label: l10n.playerAppearanceBottomPadding,
          value: style.verticalPosition,
          onChanged: (val) => onChanged(style.copyWith(verticalPosition: val)),
          onChangeEnd: (val) =>
              onChangeEnd(style.copyWith(verticalPosition: val)),
        ),
      ],
    );
  }
}

class _PositionSliderTile extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _PositionSliderTile({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingSlider(
          label: label,
          value: value,
          min: 0.0,
          max: 1.0,
          divisions: 20, // 5% steps
          valueLabelBuilder: (val) => '${(val * 100).toInt()}%',
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _AnchorLabel(label: 'BOTTOM', isSelected: value < 0.2),
              _AnchorLabel(
                label: 'MIDDLE',
                isSelected: value > 0.4 && value < 0.6,
              ),
              _AnchorLabel(label: 'TOP', isSelected: value > 0.8),
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
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: isSelected ? AppTheme.accent : AppTheme.textMuted.withAlpha(128),
        letterSpacing: 1.1,
      ),
    );
  }
}

class _ColorSelectorTile extends StatelessWidget {
  final String label;
  final Color selectedColor;
  final List<Color> colors;
  final ValueChanged<Color> onColorSelected;

  const _ColorSelectorTile({
    required this.label,
    required this.selectedColor,
    required this.colors,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DesktopTypography.subtitle),
          const SizedBox(height: 12),
          SizedBox(
            // Room for the focused circle's zoom and ring.
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: colors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final color = colors[index];
                // Handle both direct reference and hex match for consistency
                final isSelected = color.toARGB32() == selectedColor.toARGB32();

                // DpadFocusable, not GestureDetector: reachable with a
                // remote and arrow keys (REV-84).
                return Center(
                  child: DpadFocusable(
                    onTap: () => onColorSelected(color),
                    borderRadius: BorderRadius.circular(18),
                    scale: 1.15,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppTheme.accent : Colors.white24,
                          width: isSelected ? 3 : 1,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: AppTheme.accent.withAlpha(102),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                        ],
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check,
                              size: 20,
                              color: color.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
