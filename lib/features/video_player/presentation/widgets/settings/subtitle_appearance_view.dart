import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/settings/application/local_settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_color_picker.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_style_slider.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// The Look tab: the subtitle look controls themselves, so the subtitles on
/// the video change while they move. Every change is kept at once: the look
/// is saved on the device like in Settings → Subtitles, the sync holds for
/// this video.
class SubtitleAppearanceView extends ConsumerWidget {
  final CinemaPlayerState state;
  final PlayerParams params;

  const SubtitleAppearanceView({
    super.key,
    required this.state,
    required this.params,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(
      localSettingsProvider.select((s) => s.subtitleStyle),
    );
    final delay =
        ref.watch(
          playerControllerProvider(
            params,
          ).select((s) => s.value?.subtitleDelay),
        ) ??
        state.subtitleDelay;
    final looks = ref.read(localSettingsProvider.notifier);
    final controller = ref.read(playerControllerProvider(params).notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SyncControl(value: delay, onChanged: controller.updateSubtitleDelay),
          for (final kind in const [
            SubtitleStyleSliderKind.fontSize,
            SubtitleStyleSliderKind.position,
            SubtitleStyleSliderKind.background,
          ])
            SubtitleStyleSlider(
              kind: kind,
              style: style,
              onChanged: looks.previewSubtitleStyle,
              onChangeEnd: looks.updateSubtitleStyle,
            ),
          SubtitleColorPicker(
            selectedColor: style.color,
            onColorSelected: (color) =>
                looks.updateSubtitleStyle(style.copyWith(color: color)),
          ),
          const SizedBox(height: 16),
          _ResetButton(
            onPressed: () {
              looks.updateSubtitleStyle(const SubtitleStyle());
              controller.updateSubtitleDelay(0);
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// The subtitle sync: its value and the step buttons, laid out like the
/// sliders under it.
class _SyncControl extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _SyncControl({required this.value, required this.onChanged});

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
              Flexible(
                child: Text(
                  AppLocalizations.of(context)!.playerSubtitleSync,
                  style: DesktopTypography.subtitle,
                ),
              ),
              Text(
                '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}s',
                style: DesktopTypography.bodyPrimary.copyWith(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // A narrow panel wraps the buttons onto a second line.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _StepButton(label: '-5', onTap: () => onChanged(value - 5.0)),
              _StepButton(label: '-1', onTap: () => onChanged(value - 1.0)),
              _StepButton(
                label: '-.1',
                // The smallest step: an OK pressed by mistake costs little.
                autofocus: true,
                onTap: () => onChanged(_round(value - 0.1)),
              ),
              _StepButton(
                label: '+.1',
                onTap: () => onChanged(_round(value + 0.1)),
              ),
              _StepButton(label: '+1', onTap: () => onChanged(value + 1.0)),
              _StepButton(label: '+5', onTap: () => onChanged(value + 5.0)),
            ],
          ),
        ],
      ),
    );
  }

  double _round(double v) => (v * 10).roundToDouble() / 10;
}

class _StepButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool autofocus;

  const _StepButton({
    required this.label,
    required this.onTap,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      onTap: onTap,
      autofocus: autofocus,
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

/// Puts the standard look and no sync back.
class _ResetButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ResetButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.refresh, size: 16, color: AppTheme.accent),
        label: Text(
          AppLocalizations.of(context)!.playerAppearanceReset,
          style: const TextStyle(color: AppTheme.accent, fontSize: 12),
        ),
      ),
    );
  }
}
