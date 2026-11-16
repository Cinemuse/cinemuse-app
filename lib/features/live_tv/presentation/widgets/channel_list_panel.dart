import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/presentation/theme/breakpoints.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/domain/channel_model.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_list_view.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_search_field.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/live_tv_options_button.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// Minimalist Live TV channel list panel.
///
/// Supports standard split-screen presentation or high-performance
/// zero-blur drawer overlay when playing in full-window/fullscreen.
class ChannelListPanel extends ConsumerWidget {
  final bool isOverlay;
  final VoidCallback? onClose;

  /// Phone list: tapping the playing channel opens the big player (REV-132).
  final ValueChanged<Channel>? onOpenPlayer;

  const ChannelListPanel({
    super.key,
    this.isOverlay = false,
    this.onClose,
    this.onOpenPlayer,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isOverlay) {
      return Focus(
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          if (event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.gameButtonB ||
              event.logicalKey == LogicalKeyboardKey.goBack) {
            onClose?.call();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primary.withValues(alpha: 0.98),
                AppTheme.secondary.withValues(alpha: 0.97),
              ],
            ),
            border: Border(right: BorderSide(color: AppTheme.border, width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 32,
                spreadRadius: 2,
                offset: const Offset(6, 0),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildOverlayHeader(context, ref),
              const Divider(height: 1, color: Colors.white10),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: ChannelSearchField(
                  onClose: onClose,
                  onOutsideSearch: (_) => _selectFirstMatch(context, ref),
                ),
              ),
              const Divider(height: 1, color: Colors.white10),
              Expanded(
                child: ChannelListView(isOverlay: true, onClose: onClose),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.6),
        border: _resolveBorder(context),
      ),
      child: Column(
        children: [
          _PanelToolbar(
            onOutsideSearch: (_) => _selectFirstMatch(context, ref),
          ),
          const Divider(height: 1, color: Colors.white10),
          Expanded(child: ChannelListView(onOpenPlayer: onOpenPlayer)),
        ],
      ),
    );
  }

  Widget _buildOverlayHeader(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final channelsCount = ref.watch(filteredChannelsProvider).value?.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border, width: 1),
            ),
            child: const Icon(
              Icons.tv_rounded,
              size: 18,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            l10n.liveTvChannels,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
              letterSpacing: 0.3,
            ),
          ),
          if (channelsCount != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border, width: 0.8),
              ),
              child: Text(
                '$channelsCount',
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const Spacer(),
          DpadFocusable(
            tooltip: l10n.commonClose,
            onTap: onClose,
            borderRadius: BorderRadius.circular(8),
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent) return KeyEventResult.ignored;
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                onClose?.call();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            builder: (context, isFocused, isHovered, _) => Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isFocused || isHovered
                    ? AppTheme.accentHoverBg
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
            child: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  /// A search set from a sport card on Home tunes to its first channel.
  void _selectFirstMatch(BuildContext context, WidgetRef ref) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final first = ref.read(filteredChannelsProvider).value?.firstOrNull;
      if (first != null) {
        ref.read(selectedChannelProvider.notifier).select(first);
      }
    });
  }

  BoxBorder? _resolveBorder(BuildContext context) {
    final isMobile = Breakpoints.isCompact(context);
    if (isMobile) return null;
    return Border(
      right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
    );
  }
}

/// The split screen's top row: the search, then the Favourites and Recent
/// switches and the filter button.
class _PanelToolbar extends ConsumerWidget {
  final ValueChanged<String> onOutsideSearch;

  const _PanelToolbar({required this.onOutsideSearch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final currentTab = ref.watch(liveTvTabProvider);
    final filterIsActive = ref.watch(
      channelFilterProvider.select((f) => f.isActive),
    );
    final isMobile = Breakpoints.isCompact(context);

    // Each switch turns its tab on, or back to All when it is on.
    void toggleTab(LiveTvTab tab) => ref
        .read(liveTvTabProvider.notifier)
        .set(currentTab == tab ? LiveTvTab.all : tab);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SizedBox(
        height: isMobile ? 48 : 52,
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: isMobile ? 8 : 16, right: 4),
                child: ChannelSearchField(onOutsideSearch: onOutsideSearch),
              ),
            ),
            IconButton(
              onPressed: () => toggleTab(LiveTvTab.favorites),
              icon: Icon(
                currentTab == LiveTvTab.favorites
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 20,
                color: currentTab == LiveTvTab.favorites
                    ? Colors.amber
                    : Colors.white30,
              ),
              tooltip: l10n.liveTvTabFavorites,
            ),
            IconButton(
              onPressed: () => toggleTab(LiveTvTab.recents),
              icon: Icon(
                Icons.history_rounded,
                size: 20,
                color: currentTab == LiveTvTab.recents
                    ? Colors.white
                    : Colors.white30,
              ),
              tooltip: l10n.liveTvTabRecents,
            ),
            LiveTvOptionsButton(isActive: filterIsActive),
          ],
        ),
      ),
    );
  }
}
