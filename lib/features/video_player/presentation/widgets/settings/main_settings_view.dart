import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'settings_widgets.dart';

// The enumeration is still in the main file, but we use strings or integers if needed.
// However, it's better to pass a callback that handles the navigation logic.

class MainSettingsView extends ConsumerWidget {
  final CinemaPlayerState state;
  final void Function(String) onNavigate;

  const MainSettingsView({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

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
                  color: AppTheme.textWhite.withOpacity(0.9),
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
              onTap: () => onNavigate('quality'),
              compact: isLandscape,
            ),
            SettingsTile(
              icon: Icons.audiotrack_rounded,
              title: l10n.playerAudio,
              subtitle: TrackSubtitle(state: state, isSubtitle: false),
              onTap: () => onNavigate('audio'),
              compact: isLandscape,
            ),
            SettingsTile(
              icon: Icons.subtitles_rounded,
              title: l10n.playerSubtitles,
              subtitle: TrackSubtitle(state: state, isSubtitle: true),
              onTap: () => onNavigate('subtitles'),
              compact: isLandscape,
            ),
            SettingsTile(
              icon: Icons.style_outlined,
              title: l10n.playerSubtitleAppearance,
              onTap: () => onNavigate('appearance'),
              compact: isLandscape,
            ),
            SizedBox(height: isLandscape ? 12 : 24),
          ],
        ),
      ),
    );
  }
}
