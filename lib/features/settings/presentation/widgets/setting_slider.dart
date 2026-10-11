import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

class SettingSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  /// Called once when the drag ends: save here, not in [onChanged].
  final ValueChanged<double>? onChangeEnd;
  final String Function(double)? valueLabelBuilder;

  const SettingSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    this.onChangeEnd,
    this.valueLabelBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: DesktopTypography.subtitle),
              Text(
                valueLabelBuilder?.call(value) ?? value.toInt().toString(),
                style: DesktopTypography.bodyPrimary.copyWith(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
              tickMarkShape: divisions != null
                  ? const RoundSliderTickMarkShape(tickMarkRadius: 1.5)
                  : null,
              activeTickMarkColor: divisions != null
                  ? AppTheme.accent.withValues(alpha: 0.5)
                  : null,
              inactiveTickMarkColor: divisions != null ? Colors.white24 : null,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ],
      ),
    );
  }
}
