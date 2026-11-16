import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_filter_sheet.dart';

/// What the channel list and the guide show when [tab] has no channels:
/// on All, a button to the playlists.
class ChannelListEmptyState extends StatelessWidget {
  final LiveTvTab tab;

  const ChannelListEmptyState({super.key, required this.tab});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (title, subtitle, icon) = switch (tab) {
      LiveTvTab.favorites => (
        l10n.liveTvNoFavorites,
        l10n.liveTvNoFavoritesHint,
        Icons.star_outline_rounded,
      ),
      LiveTvTab.recents => (l10n.liveTvNoRecents, null, Icons.history_rounded),
      LiveTvTab.all => (l10n.liveTvNoChannels, null, Icons.tv_off_rounded),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (tab == LiveTvTab.all) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => showChannelFilterSheet(
                  context,
                  initialTab: LiveTvSheetTab.playlists,
                ),
                icon: const Icon(Icons.playlist_add_rounded, size: 20),
                label: Text(l10n.liveTvManagePlaylists),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
