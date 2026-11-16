import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/video_player/application/player_provider.dart';
import 'package:cinemuse_app/features/video_player/domain/player_models.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'selectable_option_tile.dart';
import 'settings_headers.dart';

/// The live TV panel's picture sizes: each size the playing stream holds,
/// biggest first, the biggest ticked until the user picks another. A pick
/// reopens the stream at that size; the panel stays open with the tick on
/// it. Nothing when the stream hasn't said its sizes.
class LivePictureSizeSection extends ConsumerWidget {
  final CinemaPlayerState state;
  final PlayerParams params;

  const LivePictureSizeSection({
    super.key,
    required this.state,
    required this.params,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // The panel stays open after a pick: the ticks follow the player.
    final sizes = (ref.watch(playerControllerProvider(params)).value ?? state)
        .live
        .pictureSizes;
    if (sizes.heights.isEmpty) return const SizedBox.shrink();
    final ticked = sizes.picked ?? sizes.heights.first;

    void pick(int height) => ref
        .read(playerControllerProvider(params).notifier)
        .pickPictureSize(height);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionTitle(l10n.playerPictureSize),
        for (final height in sizes.heights)
          _PictureSizeTile(
            label: LivePictureSizes.label(height),
            isSelected: height == ticked,
            autofocus: height == ticked,
            onTap: () => pick(height),
          ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PictureSizeTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onTap;

  const _PictureSizeTile({
    required this.label,
    required this.isSelected,
    required this.autofocus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableOptionTile(
      isSelected: isSelected,
      autofocus: autofocus,
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? AppTheme.textWhite
              : AppTheme.textWhite.withValues(alpha: 0.9),
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }
}
