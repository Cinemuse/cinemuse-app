import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/live_tv/domain/stream_link.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'live_picture_size_section.dart';
import 'selectable_option_tile.dart';
import 'settings_headers.dart';

class LiveTvQualityView extends ConsumerWidget {
  final CinemaPlayerState state;
  final PlayerParams params;

  const LiveTvQualityView({
    super.key,
    required this.state,
    required this.params,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final links = state.live.channel?.links ?? [];
    final activeUrl = state.live.link?.url;
    final hasActive = links.any((l) => l.url == activeUrl);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // First, so its autofocus wins over the sources'.
        LivePictureSizeSection(state: state, params: params),
        if (links.isNotEmpty) ...[
          SettingsSectionTitle(l10n.playerLiveSources),
          for (final (index, link) in links.indexed)
            _LiveSourceTile(
              link: link,
              isActive: link.url == activeUrl,
              autofocus: link.url == activeUrl || (!hasActive && index == 0),
              // The stream reloads: the panel closes, the keys go back to
              // the player.
              onTap: () {
                ref
                    .read(playerControllerProvider(params).notifier)
                    .switchLiveSource(link);
                Navigator.of(context).pop();
              },
            ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _LiveSourceTile extends StatelessWidget {
  final StreamLink link;
  final bool isActive;
  final bool autofocus;
  final VoidCallback onTap;

  const _LiveSourceTile({
    required this.link,
    required this.isActive,
    required this.autofocus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableOptionTile(
      isSelected: isActive,
      autofocus: autofocus,
      onTap: onTap,
      child: Text(
        link.displayProvider,
        style: TextStyle(
          color: isActive
              ? AppTheme.textWhite
              : AppTheme.textWhite.withValues(alpha: 0.9),
          fontSize: 14,
          fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }
}
