import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'dart:ui';

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
    final localSettings = ref.watch(localSettingsProvider);

    String title = '';
    Widget control = const SizedBox.shrink();
    VoidCallback? onReset;
    VoidCallback? onSave;

    final currentStyle = state.customSubtitleStyle ?? localSettings.subtitleStyle;

    switch (type) {
      case SliderOverlayType.sync:
        title = l10n.playerSubtitleSync;
        control = _SyncButtonControl(
          value: state.subtitleDelay,
          onChanged: (val) => controller.updateSubtitleDelay(val),
        );
        onReset = () => controller.updateSubtitleDelay(0.0);
        break;
      case SliderOverlayType.fontSize:
        title = l10n.playerAppearanceFontSize;
        control = _SliderControl(
          value: currentStyle.fontSize,
          min: 12.0,
          max: 48.0,
          labelBuilder: (v) => '${v.toInt()} px',
          onChanged: (val) => controller.updateSubtitleStyle(currentStyle.copyWith(fontSize: val)),
        );
        onReset = () => controller.updateSubtitleStyle(currentStyle.copyWith(fontSize: 24.0));
        onSave = () => localNotifier.updateSubtitleStyle(currentStyle);
        break;
      case SliderOverlayType.position:
        title = l10n.playerAppearanceBottomPadding;
        control = _SliderControl(
          value: currentStyle.verticalPosition,
          min: 0.0,
          max: 1.0,
          divisions: 20,
          labelBuilder: (v) => '${(v * 100).toInt()}%',
          onChanged: (val) => controller.updateSubtitleStyle(currentStyle.copyWith(verticalPosition: val)),
        );
        onReset = () => controller.updateSubtitleStyle(currentStyle.copyWith(verticalPosition: 0.05));
        onSave = () => localNotifier.updateSubtitleStyle(currentStyle);
        break;
      case SliderOverlayType.background:
        title = l10n.playerAppearanceBackground;
        control = _SliderControl(
          value: currentStyle.backgroundColor.a,
          min: 0.0,
          max: 1.0,
          labelBuilder: (v) => '${(v * 100).toInt()}%',
          onChanged: (val) {
            controller.updateSubtitleStyle(currentStyle.copyWith(
              backgroundColor: Colors.black.withValues(alpha: val),
            ));
          },
        );
        onReset = () => controller.updateSubtitleStyle(currentStyle.copyWith(backgroundColor: Colors.transparent));
        onSave = () => localNotifier.updateSubtitleStyle(currentStyle);
        break;
      case SliderOverlayType.color:
        title = l10n.playerAppearanceTextColor;
        control = _ColorControl(
          selectedColor: currentStyle.color,
          onColorSelected: (color) => controller.updateSubtitleStyle(currentStyle.copyWith(color: color)),
        );
        onReset = () => controller.updateSubtitleStyle(currentStyle.copyWith(color: Colors.white));
        onSave = () => localNotifier.updateSubtitleStyle(currentStyle);
        break;
      case SliderOverlayType.none:
        break;
    }

    return Stack(
      children: [
        // Backdrop scrim to close
        GestureDetector(
          onTap: () => onClose(false),
          child: Container(
            color: Colors.black26,
          ),
        ),
        
        // Floating Panel
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  width: 380,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          if (onReset != null)
                            TextButton.icon(
                              onPressed: onReset,
                              icon: const Icon(Icons.refresh, size: 16, color: AppTheme.accent),
                              label: Text(
                                l10n.playerAppearanceReset,
                                style: const TextStyle(color: AppTheme.accent, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Control
                      control,
                      
                      const SizedBox(height: 24),
                      
                      // Action Buttons
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
          ),
        ),
      ],
    );
  }
}

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
        Text(
          labelBuilder(value),
          style: const TextStyle(
            color: AppTheme.accent,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
            activeTrackColor: AppTheme.accent,
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.white,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _SyncButtonControl extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _SyncButtonControl({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}s',
          style: const TextStyle(
            color: AppTheme.accent,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StepButton(label: '-5', onTap: () => onChanged(value - 5.0)),
            _StepButton(label: '-1', onTap: () => onChanged(value - 1.0)),
            _StepButton(label: '-.1', onTap: () => onChanged(_round(value - 0.1))),
            const SizedBox(width: 8),
            _StepButton(label: '+.1', onTap: () => onChanged(_round(value + 0.1))),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 44,
            height: 40,
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
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
    final colors = const [
      Colors.white,
      Colors.yellow,
      Colors.lightGreenAccent,
      Colors.cyanAccent,
      Colors.blueAccent,
      Colors.purpleAccent,
      Colors.redAccent,
      Colors.orangeAccent,
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: colors.map((color) {
        final isSelected = color.toARGB32() == selectedColor.toARGB32();
        return GestureDetector(
          onTap: () => onColorSelected(color),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white24,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.4), // 100/255 approx 0.4
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ] : null,
            ),
            child: isSelected ? Icon(
              Icons.check,
              color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            ) : null,
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
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? AppTheme.accent : Colors.white10,
          foregroundColor: isPrimary ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
        ),
      ),
    );
  }
}
