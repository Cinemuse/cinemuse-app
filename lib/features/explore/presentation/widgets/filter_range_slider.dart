import 'package:flutter/material.dart';
import '../../../../core/presentation/theme/app_theme.dart';

/// A range slider that reports its value only when the drag ends, so a
/// drag starts one TMDB request instead of dozens.
class FilterRangeSlider extends StatefulWidget {
  final double min;
  final double max;
  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;
  final String label;
  final String Function(RangeValues values) formatValue;
  final IconData icon;

  const FilterRangeSlider({
    super.key,
    required this.min,
    required this.max,
    required this.values,
    required this.onChanged,
    required this.label,
    required this.formatValue,
    required this.icon,
  });

  @override
  State<FilterRangeSlider> createState() => _FilterRangeSliderState();
}

class _FilterRangeSliderState extends State<FilterRangeSlider> {
  // The value while dragging; null when not dragging.
  RangeValues? _dragValues;

  @override
  Widget build(BuildContext context) {
    final values = _dragValues ?? widget.values;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            Text(
              widget.formatValue(values),
              style: const TextStyle(
                color: AppTheme.accent,
                fontFamily: 'monospace',
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: AppTheme.accent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: Colors.white,
            overlayColor: AppTheme.accent.withValues(alpha: 0.2),
            rangeThumbShape: const RoundRangeSliderThumbShape(
              enabledThumbRadius: 8,
              elevation: 4,
            ),
            rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
          ),
          child: RangeSlider(
            values: values,
            min: widget.min,
            max: widget.max,
            onChanged: (v) => setState(() => _dragValues = v),
            onChangeEnd: (v) {
              setState(() => _dragValues = null);
              widget.onChanged(v);
            },
          ),
        ),
      ],
    );
  }
}
