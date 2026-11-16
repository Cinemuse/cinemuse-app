import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';

class SettingSlider extends StatelessWidget {
  /// Null where a title above already names it (the player's subtitle panel).
  final String? label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  /// Called once when the drag ends: save here, not in [onChanged].
  final ValueChanged<double>? onChangeEnd;
  final String Function(double)? valueLabelBuilder;
  final bool autofocus;

  const SettingSlider({
    super.key,
    this.label,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.onChanged,
    this.onChangeEnd,
    this.valueLabelBuilder,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    // Like the settings rows, the ring goes on the block's own edge (REV-263).
    return FocusRingFollower(
      borderRadius: BorderRadius.circular(16),
      isInside: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: label == null
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.spaceBetween,
              children: [
                // Flexible: a long label wraps instead of pushing the value
                // off a narrow phone.
                if (label != null)
                  Flexible(
                    child: Text(label!, style: DesktopTypography.subtitle),
                  ),
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
                inactiveTickMarkColor: divisions != null
                    ? Colors.white24
                    : null,
              ),
              // Directional: only ← / → change it; ↑ / ↓ leave it
              // (REV-282, REV-332).
              child: MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(navigationMode: NavigationMode.directional),
                child: Slider(
                  value: value,
                  min: min,
                  max: max,
                  divisions: divisions,
                  autofocus: autofocus,
                  onChanged: onChanged,
                  onChangeEnd: onChangeEnd,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
