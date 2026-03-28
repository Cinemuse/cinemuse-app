import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/subtitle_style.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/settings/presentation/widgets/subtitle_appearance_form.dart';
import 'settings_widgets.dart';

class SubtitleAppearanceView extends ConsumerWidget {
  final CinemaPlayerState state;
  final PlayerParams params;
  final VoidCallback onBack;

  const SubtitleAppearanceView({
    super.key,
    required this.state,
    required this.params,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final currentStyle = state.customSubtitleStyle ??
        SubtitleStyle(
          fontSize: settings.subtitleFontSize,
          color: SubtitleStyle.hexToColor(settings.subtitleColor),
          backgroundColor: SubtitleStyle.hexToColor(settings.subtitleBackgroundColor),
          verticalPosition: settings.subtitleVerticalPosition,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SubViewHeader(
          title: l10n.playerSubtitleAppearance,
          onBack: onBack,
        ),
        
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Shared Form for content (includes preview now)
                SubtitleAppearanceForm(
                  style: currentStyle,
                  onChanged: (newStyle) {
                    ref.read(playerControllerProvider(params).notifier)
                       .updateSubtitleStyle(newStyle);
                  },
                ),
        
                const SizedBox(height: 24),
                
                // Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: l10n.playerAppearanceReset,
                          isSecondary: true,
                           onPressed: () {
                             ref.read(playerControllerProvider(params).notifier)
                                .updateSubtitleStyle(SubtitleStyle(
                                  fontSize: settings.subtitleFontSize,
                                  color: SubtitleStyle.hexToColor(settings.subtitleColor),
                                  backgroundColor: SubtitleStyle.hexToColor(settings.subtitleBackgroundColor),
                                  verticalPosition: settings.subtitleVerticalPosition,
                                ));
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionButton(
                          label: l10n.playerAppearanceSaveDefault,
                          onPressed: () {
                            ref.read(settingsProvider.notifier).updateSettings({
                              'subtitleFontSize': currentStyle.fontSize,
                              'subtitleColor': SubtitleStyle.colorToHex(currentStyle.color),
                              'subtitleBackgroundColor': SubtitleStyle.colorToHex(currentStyle.backgroundColor),
                              'subtitleVerticalPosition': currentStyle.verticalPosition,
                            });
                            // Refresh local override since it's now global
                            ref.read(playerControllerProvider(params).notifier)
                               .updateSubtitleStyle(currentStyle);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// Keep only _SubtitlePreview and _ActionButton as they are player-specific
class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isSecondary;

  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSecondary ? Colors.white10 : AppTheme.accent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isSecondary ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
