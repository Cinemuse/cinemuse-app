import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'settings_widgets.dart';

class SubtitleAppearanceView extends ConsumerWidget {
  final CinemaPlayerState state;
  final PlayerParams params;
  final VoidCallback onBack;
  final ValueChanged<SliderOverlayType> onOverlayRequested;

  const SubtitleAppearanceView({
    super.key,
    required this.state,
    required this.params,
    required this.onBack,
    required this.onOverlayRequested,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubViewHeader(title: l10n.playerSubtitleAppearance, onBack: onBack),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTile(
                  context,
                  icon: Icons.timer_outlined,
                  title: l10n.playerSubtitleSync,
                  value:
                      '${state.subtitleDelay >= 0 ? '+' : ''}${state.subtitleDelay.toStringAsFixed(1)}s',
                  overlayType: SliderOverlayType.sync,
                ),
                _buildTile(
                  context,
                  icon: Icons.text_fields_rounded,
                  title: l10n.playerAppearanceFontSize,
                  value:
                      '${state.customSubtitleStyle?.fontSize.toInt() ?? 24} px',
                  overlayType: SliderOverlayType.fontSize,
                ),
                _buildTile(
                  context,
                  icon: Icons.vertical_align_bottom_rounded,
                  title: l10n.playerAppearanceBottomPadding,
                  value:
                      '${((state.customSubtitleStyle?.verticalPosition ?? 0.05) * 100).toInt()}%',
                  overlayType: SliderOverlayType.position,
                ),
                _buildTile(
                  context,
                  icon: Icons.opacity_rounded,
                  title: l10n.playerAppearanceBackground,
                  value:
                      '${((state.customSubtitleStyle?.backgroundColor.a ?? 0) * 100).toInt()}%',
                  overlayType: SliderOverlayType.background,
                ),
                _buildTile(
                  context,
                  icon: Icons.palette_outlined,
                  title: l10n.playerAppearanceTextColor,
                  overlayType: SliderOverlayType.color,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? value,
    required SliderOverlayType overlayType,
  }) {
    return SettingsTile(
      icon: icon,
      title: title,
      subtitle: value != null
          ? Text(
              value,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            )
          : null,
      onTap: () {
        onOverlayRequested(overlayType);
        Navigator.pop(context);
      },
    );
  }
}
