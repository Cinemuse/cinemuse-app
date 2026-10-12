import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'settings_widgets.dart';

/// The views available inside the player's settings sheet. Here, not in
/// the sheet: the sheet imports this menu, which navigates with it.
enum SettingsView { main, quality, audio, subtitles, appearance }

class MainSettingsView extends StatelessWidget {
  final CinemaPlayerState state;
  final ValueChanged<SettingsView> onNavigate;

  const MainSettingsView({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(isLandscape ? 16.0 : 24.0),
              child: Text(
                l10n.playerSettings.toUpperCase(),
                style: TextStyle(
                  color: AppTheme.textWhite.withValues(alpha: 0.9),
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            SettingsTile(
              icon: Icons.high_quality_rounded,
              title: l10n.playerQuality,
              subtitle: QualitySubtitle(state: state),
              onTap: () => onNavigate(SettingsView.quality),
              compact: isLandscape,
              autofocus: true,
            ),
            if (!state.isLive) ...[
              SettingsTile(
                icon: Icons.audiotrack_rounded,
                title: l10n.playerAudio,
                subtitle: TrackSubtitle(state: state, isSubtitle: false),
                onTap: () => onNavigate(SettingsView.audio),
                compact: isLandscape,
              ),
              SettingsTile(
                icon: Icons.subtitles_rounded,
                title: l10n.playerSubtitles,
                subtitle: TrackSubtitle(state: state, isSubtitle: true),
                onTap: () => onNavigate(SettingsView.subtitles),
                compact: isLandscape,
              ),
              SettingsTile(
                icon: Icons.style_outlined,
                title: l10n.playerSubtitleAppearance,
                onTap: () => onNavigate(SettingsView.appearance),
                compact: isLandscape,
              ),
            ],
            SizedBox(height: isLandscape ? 12 : 24),
          ],
        ),
      ),
    );
  }
}
