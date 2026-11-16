import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/live_tv/application/live_tv_providers.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_filter_sheet.dart';
import 'package:cinemuse_app/features/live_tv/presentation/widgets/channel_search_field.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// The guide's top bar: search, the All / Favorites / Recents tabs, "Jump to
/// Live" and the options button, lit while a category is picked. Up and Down
/// move one layer at a time: the app's menu bar, this row, the guide.
class GuideTopBar extends ConsumerStatefulWidget {
  /// Given to the search box, so the screen is entered on it.
  final FocusNode? focusNode;
  final VoidCallback onJumpToNow;

  /// Down from the row.
  final VoidCallback onDownToGuide;

  const GuideTopBar({
    super.key,
    this.focusNode,
    required this.onJumpToNow,
    required this.onDownToGuide,
  });

  @override
  ConsumerState<GuideTopBar> createState() => GuideTopBarState();
}

class GuideTopBarState extends ConsumerState<GuideTopBar> {
  final _ownSearchNode = FocusNode(debugLabel: 'GuideSearch');
  final _allNode = FocusNode(debugLabel: 'GuideTabAll');
  final _favoritesNode = FocusNode(debugLabel: 'GuideTabFavorites');
  final _recentsNode = FocusNode(debugLabel: 'GuideTabRecents');

  @override
  void dispose() {
    _ownSearchNode.dispose();
    _allNode.dispose();
    _favoritesNode.dispose();
    _recentsNode.dispose();
    super.dispose();
  }

  FocusNode get _searchNode => widget.focusNode ?? _ownSearchNode;

  FocusNode _tabNode(LiveTvTab tab) => switch (tab) {
    LiveTvTab.all => _allNode,
    LiveTvTab.favorites => _favoritesNode,
    LiveTvTab.recents => _recentsNode,
  };

  /// Up from the guide: the row's start.
  void focusFromBelow() => _searchNode.requestFocus();

  void _focusNavbar() => ref.read(topNavbarFocusActionProvider)?.call();

  KeyEventResult _onRowKey(
    FocusNode node,
    KeyEvent event, {
    bool isLast = false,
    VoidCallback? onLeft,
  }) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      final focusNavbar = ref.read(topNavbarFocusActionProvider);
      if (focusNavbar == null) return KeyEventResult.ignored;
      focusNavbar();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      widget.onDownToGuide();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight && isLast) {
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && onLeft != null) {
      onLeft();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final activeTab = ref.watch(liveTvTabProvider);
    final filterIsActive = ref.watch(
      channelFilterProvider.select((f) => f.isActive),
    );

    Widget tab(LiveTvTab value, IconData icon, String label) => _TabButton(
      focusNode: _tabNode(value),
      icon: icon,
      label: label,
      isSelected: activeTab == value,
      onTap: () => ref.read(liveTvTabProvider.notifier).set(value),
      // Told, not guessed: Left from All is the search box.
      onKeyEvent: value == LiveTvTab.all
          ? (node, event) => _onRowKey(node, event, onLeft: focusFromBelow)
          : _onRowKey,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        border: Border(bottom: BorderSide(color: AppTheme.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: ChannelSearchField(
              focusNode: _searchNode,
              onUp: _focusNavbar,
              onDown: widget.onDownToGuide,
              // The row's start: Left stays.
              onLeft: () {},
              onRight: _tabNode(LiveTvTab.all).requestFocus,
            ),
          ),
          const SizedBox(width: 12),
          tab(LiveTvTab.all, Icons.grid_view_rounded, l10n.liveTvTabAll),
          const SizedBox(width: 6),
          tab(LiveTvTab.favorites, Icons.star_rounded, l10n.liveTvTabFavorites),
          const SizedBox(width: 6),
          tab(LiveTvTab.recents, Icons.history_rounded, l10n.liveTvTabRecents),
          const SizedBox(width: 12),
          _BarButton(
            onTap: widget.onJumpToNow,
            onKeyEvent: _onRowKey,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.my_location_rounded,
                  size: 16,
                  color: AppTheme.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.liveTvJumpToNow,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _BarButton(
            tooltip: l10n.liveTvFilterAndPlaylists,
            isSquare: true,
            onTap: () => showChannelFilterSheet(context),
            onKeyEvent: (node, event) => _onRowKey(node, event, isLast: true),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.tune_rounded,
                  size: 18,
                  color: filterIsActive ? Colors.white : Colors.white70,
                ),
                // Lit like the channel list's options button.
                if (filterIsActive)
                  Positioned(
                    right: -5,
                    top: -5,
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
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final FocusNode? focusNode;
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final FocusOnKeyEventCallback onKeyEvent;

  const _TabButton({
    this.focusNode,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      focusNode: focusNode,
      onTap: onTap,
      onKeyEvent: onKeyEvent,
      borderRadius: BorderRadius.circular(8),
      builder: (context, isFocused, isHovered, _) {
        return Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accent.withValues(alpha: 0.2)
                : (isFocused || isHovered
                      ? AppTheme.accentHoverBg
                      : Colors.white.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppTheme.accent
                  : Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? AppTheme.accent : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}

/// "Jump to Live" and the options button.
class _BarButton extends StatelessWidget {
  final String? tooltip;
  final bool isSquare;
  final VoidCallback onTap;
  final FocusOnKeyEventCallback onKeyEvent;
  final Widget child;

  const _BarButton({
    this.tooltip,
    this.isSquare = false,
    required this.onTap,
    required this.onKeyEvent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      tooltip: tooltip,
      onTap: onTap,
      onKeyEvent: onKeyEvent,
      borderRadius: BorderRadius.circular(8),
      builder: (context, isFocused, isHovered, _) {
        return Container(
          height: 38,
          width: isSquare ? 38 : null,
          alignment: isSquare ? Alignment.center : null,
          padding: isSquare ? null : const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isFocused || isHovered
                ? AppTheme.accentHoverBg
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        );
      },
      child: const SizedBox.shrink(),
    );
  }
}
