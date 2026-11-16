import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_text_colors.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// The subtitle text colour circles, the same in Settings → Subtitles and in
/// the player's subtitle panel (REV-308).
class SubtitleColorPicker extends StatelessWidget {
  final Color selectedColor;

  /// False where a title above already names the setting.
  final bool showLabel;
  final ValueChanged<Color> onColorSelected;

  const SubtitleColorPicker({
    super.key,
    required this.selectedColor,
    this.showLabel = true,
    required this.onColorSelected,
  });

  int get _selectedIndex => subtitleTextColors.indexWhere(
    (c) => c.toARGB32() == selectedColor.toARGB32(),
  );

  /// Left and right move the tick, like a slider; at either end the key
  /// stays here, so it never jumps out of the block by surprise.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final step = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowRight => 1,
      _ => 0,
    };
    if (step == 0) return KeyEventResult.ignored;
    final next = _selectedIndex + step;
    if (next >= 0 && next < subtitleTextColors.length) {
      onColorSelected(subtitleTextColors[next]);
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    // One stop for the whole block, ringed on its edge like the settings
    // rows and the sliders (user, 2026-11-12); the circles are for the mouse
    // and touch only.
    return DpadFocusable(
      onKeyEvent: _onKey,
      borderRadius: BorderRadius.circular(16),
      isFocusRingInside: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showLabel) ...[
              Text(
                AppLocalizations.of(context)!.playerAppearanceTextColor,
                style: DesktopTypography.subtitle,
              ),
              const SizedBox(height: 12),
            ],
            // A narrow panel wraps the circles onto a second line; the padding
            // leaves room for the hovered circle's zoom.
            Padding(
              padding: const EdgeInsets.all(4),
              child: ExcludeFocus(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final color in subtitleTextColors)
                      _ColorCircle(
                        color: color,
                        isSelected:
                            color.toARGB32() == selectedColor.toARGB32(),
                        onTap: () => onColorSelected(color),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorCircle({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // DpadFocusable for the hover zoom and the hand; the block above takes
    // the keys.
    return DpadFocusable(
      onTap: onTap,
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
    );
  }
}
