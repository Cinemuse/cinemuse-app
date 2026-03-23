import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class SubtitleAppearanceForm extends StatelessWidget {
  final SubtitleStyle style;
  final ValueChanged<SubtitleStyle> onChanged;
  final bool showPreview;

  const SubtitleAppearanceForm({
    super.key,
    required this.style,
    required this.onChanged,
    this.showPreview = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showPreview) ...[
          _SubtitlePreview(
            style: style,
            label: l10n.playerAppearanceSampleText,
          ),
          const SizedBox(height: 16),
        ],
        // Font Size
        _SettingsSliderTile(
          label: l10n.playerAppearanceFontSize,
          value: style.fontSize,
          min: 12.0,
          max: 48.0,
          onChanged: (val) => onChanged(style.copyWith(fontSize: val)),
        ),

        // Text Color
        _ColorSelectorTile(
          label: l10n.playerAppearanceTextColor,
          selectedColor: style.color,
          colors: const [
            Colors.white,
            Colors.yellow,
            Colors.lightGreenAccent,
            Colors.cyanAccent,
            Colors.blueAccent,
            Colors.redAccent,
          ],
          onColorSelected: (color) => onChanged(style.copyWith(color: color)),
        ),

        // Background Opacity
        _SettingsSliderTile(
          label: l10n.playerAppearanceBackground,
          value: style.backgroundColor.a.clamp(0.0, 1.0),
          min: 0.0,
          max: 1.0,
          valueLabelBuilder: (val) => '${(val * 100).toInt()}%',
          onChanged: (val) {
            final newAlpha = (val * 255).round();
            onChanged(style.copyWith(
              backgroundColor: Colors.black.withAlpha(newAlpha),
            ));
          },
        ),

        // Vertical Position
        _PositionSliderTile(
          label: l10n.playerAppearanceBottomPadding,
          value: style.verticalPosition,
          onChanged: (val) => onChanged(style.copyWith(verticalPosition: val)),
        ),
      ],
    );
  }
}

class _SettingsSliderTile extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String Function(double)? valueLabelBuilder;

  const _SettingsSliderTile({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.valueLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final valueText = valueLabelBuilder != null ? valueLabelBuilder!(value) : value.toInt().toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: DesktopTypography.subtitle),
              Text(valueText, style: DesktopTypography.bodyPrimary.copyWith(color: AppTheme.accent, fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: Colors.white10,
              thumbColor: AppTheme.accent,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _PositionSliderTile extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  const _PositionSliderTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value * 100).toInt();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: DesktopTypography.subtitle),
              Text('$percentage%', style: DesktopTypography.bodyPrimary.copyWith(color: AppTheme.accent, fontWeight: FontWeight.bold)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: Colors.white10,
              thumbColor: AppTheme.accent,
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.5),
              activeTickMarkColor: AppTheme.accent.withAlpha(128),
              inactiveTickMarkColor: Colors.white24,
            ),
            child: Slider(
              value: value,
              min: 0.0,
              max: 1.0,
              divisions: 20, // 5% steps
              onChanged: onChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AnchorLabel(label: 'BOTTOM', isSelected: value < 0.2),
                _AnchorLabel(label: 'MIDDLE', isSelected: value > 0.4 && value < 0.6),
                _AnchorLabel(label: 'TOP', isSelected: value > 0.8),
              ],
            ),
          ),
        ],
      ),
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
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: colors.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final color = colors[index];
                // Handle both direct reference and hex match for consistency
                final isSelected = color.toARGB32() == selectedColor.toARGB32();
                
                return GestureDetector(
                  onTap: () => onColorSelected(color),
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
                            color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                          )
                        : null,
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
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1485846234645-a62644f84728?q=80&w=2059&auto=format&fit=crop'),
          fit: BoxFit.cover,
          opacity: 0.3,
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
