import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/application/subtitle_style_provider.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_text_colors.dart';
import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

class SubtitleSliderOverlay extends ConsumerWidget {
  final SliderOverlayType type;
  final PlayerParams params;
  final CinemaPlayerState state;
  final void Function(bool) onClose;

  const SubtitleSliderOverlay({
    super.key,
    required this.type,
    required this.params,
    required this.state,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (type == SliderOverlayType.none) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(playerControllerProvider(params).notifier);
    final localNotifier = ref.read(localSettingsProvider.notifier);

    String title = '';
    Widget control = const SizedBox.shrink();
    late final VoidCallback onReset;

    final currentStyle = ref.watch(effectiveSubtitleStyleProvider(params));
    const defaults = SubtitleStyle();
    final VoidCallback? onSave = type == SliderOverlayType.sync
        ? null
        : () => localNotifier.updateSubtitleStyle(currentStyle);

    switch (type) {
      case SliderOverlayType.sync:
        title = l10n.playerSubtitleSync;
        control = _SyncButtonControl(
          value: state.subtitleDelay,
          onChanged: controller.updateSubtitleDelay,
        );
        onReset = () => controller.updateSubtitleDelay(0.0);
      case SliderOverlayType.fontSize:
        title = l10n.playerAppearanceFontSize;
        control = _SliderControl(
          value: currentStyle.fontSize,
          min: 12.0,
          max: 48.0,
          labelBuilder: (v) => '${v.toInt()} px',
          onChanged: (val) => controller.updateSubtitleStyle(
            currentStyle.copyWith(fontSize: val),
          ),
        );
        onReset = () => controller.updateSubtitleStyle(
          currentStyle.copyWith(fontSize: defaults.fontSize),
        );
      case SliderOverlayType.position:
        title = l10n.playerAppearanceBottomPadding;
        control = _SliderControl(
          value: currentStyle.verticalPosition,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          labelBuilder: (v) => '${(v * 100).toInt()}%',
          onChanged: (val) => controller.updateSubtitleStyle(
            currentStyle.copyWith(verticalPosition: val),
          ),
        );
        onReset = () => controller.updateSubtitleStyle(
          currentStyle.copyWith(verticalPosition: defaults.verticalPosition),
        );
      case SliderOverlayType.background:
        title = l10n.playerAppearanceBackground;
        control = _SliderControl(
          value: currentStyle.backgroundColor.a,
          min: 0.0,
          max: 1.0,
          labelBuilder: (v) => '${(v * 100).toInt()}%',
          onChanged: (val) {
            controller.updateSubtitleStyle(
              currentStyle.copyWith(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.scrim.withValues(alpha: val),
              ),
            );
          },
        );
        onReset = () => controller.updateSubtitleStyle(
          currentStyle.copyWith(backgroundColor: defaults.backgroundColor),
        );
      case SliderOverlayType.color:
        title = l10n.playerAppearanceTextColor;
        control = _ColorControl(
          selectedColor: currentStyle.color,
          onColorSelected: (color) => controller.updateSubtitleStyle(
            currentStyle.copyWith(color: color),
          ),
        );
        onReset = () => controller.updateSubtitleStyle(
          currentStyle.copyWith(color: defaults.color),
        );
      case SliderOverlayType.none:
        break;
    }

    void cancel() => onClose(false);
    // Keys stay in the panel; Esc / Back cancel it (REV-166).
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): cancel,
        const SingleActivator(LogicalKeyboardKey.goBack): cancel,
        const SingleActivator(LogicalKeyboardKey.gameButtonB): cancel,
      },
      child: FocusScope(
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => onClose(false),
              child: Container(color: AppTheme.surfaceOverlay),
            ),
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                // No blur: it would be redone on every video frame (REV-138).
                child: Container(
                  // Narrower on small phones: 380 px cut "+5" off (REV-176).
                  constraints: const BoxConstraints(maxWidth: 380),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.8),
                    borderRadius: AppTheme.radiusXl,
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Long Italian titles must not push Reset out.
                          Expanded(
                            child: Text(
                              title.toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: onReset,
                            icon: const Icon(
                              Icons.refresh,
                              size: 16,
                              color: AppTheme.accent,
                            ),
                            label: Text(
                              l10n.playerAppearanceReset,
                              style: const TextStyle(
                                color: AppTheme.accent,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      control,
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          if (onSave != null) ...[
                            Expanded(
                              child: _OverlayButton(
                                label: l10n.commonCancel,
                                onPressed: () => onClose(false),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: _OverlayButton(
                              label: l10n.commonOk,
                              isPrimary: true,
                              onPressed: () {
                                if (onSave != null) onSave();
                                onClose(true);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The big value above a slider or the sync buttons.
const _valueStyle = TextStyle(
  color: AppTheme.accent,
  fontSize: 32,
  fontWeight: FontWeight.bold,
);

class _SliderControl extends StatelessWidget {
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String Function(double) labelBuilder;
  final ValueChanged<double> onChanged;

  const _SliderControl({
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(labelBuilder(value), style: _valueStyle),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            activeTrackColor: AppTheme.accent,
            inactiveTrackColor: AppTheme.borderSubtle,
            thumbColor: AppTheme.textWhite,
          ),
          // Directional: only ← / → change it; ↑ / ↓ leave it (REV-282).
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(navigationMode: NavigationMode.directional),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncButtonControl extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _SyncButtonControl({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}s',
          style: _valueStyle,
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            _StepButton(label: '-5', onTap: () => onChanged(value - 5.0)),
            _StepButton(label: '-1', onTap: () => onChanged(value - 1.0)),
            _StepButton(
              label: '-.1',
              onTap: () => onChanged(_round(value - 0.1)),
            ),
            const SizedBox(width: 8),
            _StepButton(
              label: '+.1',
              onTap: () => onChanged(_round(value + 0.1)),
            ),
            _StepButton(label: '+1', onTap: () => onChanged(value + 1.0)),
            _StepButton(label: '+5', onTap: () => onChanged(value + 5.0)),
          ],
        ),
      ],
    );
  }

  double _round(double v) => (v * 10).roundToDouble() / 10;
}

class _StepButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _StepButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      onTap: onTap,
      borderRadius: AppTheme.radiusMd,
      child: Container(
        width: 44,
        height: 40,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppTheme.surfaceOverlay,
          borderRadius: AppTheme.radiusMd,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.textWhite,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ColorControl extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  const _ColorControl({
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: subtitleTextColors.map((color) {
        final isSelected = color.toARGB32() == selectedColor.toARGB32();
        return DpadFocusable(
          onTap: () => onColorSelected(color),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppTheme.textWhite : AppTheme.borderSubtle,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    color: color.computeLuminance() > 0.5
                        ? AppTheme.primary
                        : AppTheme.textWhite,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _OverlayButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _OverlayButton({
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        // The main button starts focused (REV-166).
        autofocus: isPrimary,
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? AppTheme.accent
              : AppTheme.surfaceOverlay,
          foregroundColor: isPrimary ? AppTheme.primary : AppTheme.textWhite,
          shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusMd),
          elevation: 0,
        ),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
