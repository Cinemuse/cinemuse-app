import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';

/// Floating capsule at top-center displaying volume
/// or brightness percentage when dragging.
class VolumeBrightnessHud extends StatelessWidget {
  final DragType dragType;
  final double indicatorValue;

  const VolumeBrightnessHud({
    super.key,
    required this.dragType,
    required this.indicatorValue,
  });

  @override
  Widget build(BuildContext context) {
    if (dragType == DragType.none) return const SizedBox.shrink();

    final isBrightness = dragType == DragType.brightness;
    final percentage = (indicatorValue.clamp(0.0, 1.0) * 100).round();

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 36.0),
        child: IgnorePointer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceOverlay,
              borderRadius: AppTheme.radiusXl,
              border: Border.all(color: AppTheme.borderSubtle, width: 1),
              boxShadow: AppTheme.shadowNeonSm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isBrightness
                      ? Icons.brightness_6_rounded
                      : (indicatorValue <= 0
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded),
                  color: AppTheme.textWhite,
                  size: 18,
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: AppTheme.radiusSm,
                    child: LinearProgressIndicator(
                      value: indicatorValue.clamp(0.0, 1.0),
                      backgroundColor: AppTheme.borderSubtle,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppTheme.textWhite,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    color: AppTheme.textWhite.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
