import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_filter_sheet.dart';
import 'package:cinemuse_app/shared/widgets/menu/menu_focus_ring.dart';

/// The channel list's filter button: a tap opens the filter and playlists
/// sheet, a long press or right click asks which side to open. The dot shows
/// that categories are picked.
class LiveTvOptionsButton extends StatelessWidget {
  final bool isActive;

  const LiveTvOptionsButton({super.key, required this.isActive});

  Future<void> _showQuickMenu(BuildContext context, Offset position) async {
    final l10n = AppLocalizations.of(context)!;
    // fromLTRB's right/bottom are insets, not coordinates (REV-248).
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final selected = await showMenu<LiveTvSheetTab>(
      context: context,
      position: RelativeRect.fromRect(
        overlay.globalToLocal(position) & Size.zero,
        Offset.zero & overlay.size,
      ),
      color: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      items: [
        AppPopupMenuItem(
          value: LiveTvSheetTab.categories,
          child: Row(
            children: [
              const Icon(
                Icons.filter_list_rounded,
                size: 18,
                color: Colors.white70,
              ),
              const SizedBox(width: 10),
              Text(
                l10n.liveTvFilterChannels,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
        AppPopupMenuItem(
          value: LiveTvSheetTab.playlists,
          child: Row(
            children: [
              const Icon(
                Icons.playlist_play_rounded,
                size: 20,
                color: Colors.white70,
              ),
              const SizedBox(width: 10),
              Text(
                l10n.liveTvManagePlaylists,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );

    if (selected != null && context.mounted) {
      showChannelFilterSheet(context, initialTab: selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onLongPressStart: (details) =>
            _showQuickMenu(context, details.globalPosition),
        onSecondaryTapDown: (details) =>
            _showQuickMenu(context, details.globalPosition),
        child: Stack(
          children: [
            IconButton(
              onPressed: () => showChannelFilterSheet(context),
              icon: Icon(
                Icons.tune_rounded,
                size: 20,
                color: isActive ? Colors.white : Colors.white30,
              ),
              tooltip: l10n.liveTvFilterAndPlaylists,
            ),
            if (isActive)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
