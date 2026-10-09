import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/dpad_focusable.dart';

/// TV Navigation Rail providing a collapsible left-side navigation shell
/// optimized for 10-foot TV and D-pad / remote control navigation.
class TvNavigationRail extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSearchTap;
  final VoidCallback onSettingsTap;
  final VoidCallback? onExitRight;

  const TvNavigationRail({
    super.key,
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.onSearchTap,
    required this.onSettingsTap,
    this.onExitRight,
  });

  @override
  State<TvNavigationRail> createState() => TvNavigationRailState();
}

class TvNavigationRailState extends State<TvNavigationRail> {
  static const double _collapsedWidth = 76.0;
  static const double _expandedWidth = 220.0;
  static const Duration _animationDuration = Duration(milliseconds: 200);

  bool _isHovered = false;
  int _focusedIndex = -1;

  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _focusNodes = List.generate(6, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  bool get isFocused => _focusedIndex >= 0;
  bool get isExpanded => _isHovered || isFocused;

  /// Programmatically focuses the active navigation item.
  void focusActiveItem() {
    final targetIndex = (widget.currentIndex >= 0 && widget.currentIndex < 4)
        ? widget.currentIndex + 1
        : 1;
    if (targetIndex < _focusNodes.length) {
      _focusNodes[targetIndex].requestFocus();
    }
  }

  void _handleFocusChange(int itemIndex, bool hasFocus) {
    setState(() {
      if (hasFocus) {
        _focusedIndex = itemIndex;
      } else if (_focusedIndex == itemIndex) {
        _focusedIndex = -1;
      }
    });
  }

  KeyEventResult _handleItemKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    // 1. Going left while on the sidebar is disallowed (stays on sidebar, never returns to content row)
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.handled;
    }

    // 2. Going right exits the sidebar and moves focus into the main screen content
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (widget.onExitRight != null) {
        widget.onExitRight!();
        return KeyEventResult.handled;
      }
    }

    // 3. Clamp at topmost item (Search) on arrowUp and bottommost item (Settings) on arrowDown
    if (_focusNodes.isNotEmpty) {
      if (node == _focusNodes.first &&
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        return KeyEventResult.handled;
      }
      if (node == _focusNodes.last &&
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final expanded = isExpanded;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: _animationDuration,
        curve: Curves.easeOutCubic,
        width: expanded ? _expandedWidth : _collapsedWidth,
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.95),
          border: Border(
            right: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(expanded),
            const SizedBox(height: 12),
            _buildRailItem(
              itemIndex: 0,
              icon: Icons.search_rounded,
              selectedIcon: Icons.search_rounded,
              label: l10n.navSearch,
              isSelected: false,
              isExpanded: expanded,
              onTap: widget.onSearchTap,
            ),
            const SizedBox(height: 4),
            _buildRailItem(
              itemIndex: 1,
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: l10n.navHome,
              isSelected: widget.currentIndex == 0,
              isExpanded: expanded,
              onTap: () => widget.onDestinationSelected(0),
            ),
            const SizedBox(height: 4),
            _buildRailItem(
              itemIndex: 2,
              icon: Icons.explore_outlined,
              selectedIcon: Icons.explore_rounded,
              label: l10n.navExplore,
              isSelected: widget.currentIndex == 1,
              isExpanded: expanded,
              onTap: () => widget.onDestinationSelected(1),
            ),
            const SizedBox(height: 4),
            _buildRailItem(
              itemIndex: 3,
              icon: Icons.live_tv_outlined,
              selectedIcon: Icons.live_tv_rounded,
              label: l10n.navLiveTV,
              isSelected: widget.currentIndex == 2,
              isExpanded: expanded,
              onTap: () => widget.onDestinationSelected(2),
            ),
            const SizedBox(height: 4),
            _buildRailItem(
              itemIndex: 4,
              icon: Icons.video_library_outlined,
              selectedIcon: Icons.video_library_rounded,
              label: l10n.navLibrary,
              isSelected: widget.currentIndex == 3,
              isExpanded: expanded,
              onTap: () => widget.onDestinationSelected(3),
            ),
            const Spacer(),
            _buildRailItem(
              itemIndex: 5,
              icon: Icons.settings_outlined,
              selectedIcon: Icons.settings_rounded,
              label: l10n.navSettings,
              isSelected: false,
              isExpanded: expanded,
              onTap: widget.onSettingsTap,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool expanded) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/logo.png',
            height: 32,
            width: 32,
            fit: BoxFit.contain,
          ),
          ClipRect(
            child: AnimatedContainer(
              duration: _animationDuration,
              curve: Curves.easeOutCubic,
              width: expanded ? 130 : 0,
              child: AnimatedOpacity(
                duration: _animationDuration,
                opacity: expanded ? 1.0 : 0.0,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Image.asset(
                    'assets/wordmark.png',
                    height: 22,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRailItem({
    required int itemIndex,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isSelected,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final isItemFocused = _focusedIndex == itemIndex;
    final displayIcon = isSelected ? selectedIcon : icon;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DpadFocusable(
        focusNode: _focusNodes[itemIndex],
        onFocusChange: (hasFocus) => _handleFocusChange(itemIndex, hasFocus),
        onTap: onTap,
        onKeyEvent: _handleItemKeyEvent,
        scale: 1.0,
        borderRadius: BorderRadius.circular(14),
        showFocusRing: false,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: isItemFocused
                ? AppTheme.accent.withValues(alpha: 0.25)
                : isSelected
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.transparent,
            border: Border.all(
              color: isItemFocused
                  ? AppTheme.accent
                  : isSelected
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.transparent,
              width: isItemFocused ? 2 : 1,
            ),
            boxShadow: isItemFocused ? AppTheme.shadowFocusGlow : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(
                displayIcon,
                size: 22,
                color: isItemFocused
                    ? Colors.white
                    : isSelected
                    ? AppTheme.accent
                    : AppTheme.textMuted,
              ),
              ClipRect(
                child: AnimatedContainer(
                  duration: _animationDuration,
                  curve: Curves.easeOutCubic,
                  width: isExpanded ? 130 : 0,
                  child: AnimatedOpacity(
                    duration: _animationDuration,
                    opacity: isExpanded ? 1.0 : 0.0,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: isItemFocused
                              ? Colors.white
                              : isSelected
                              ? Colors.white
                              : AppTheme.textMuted,
                          fontWeight: isItemFocused || isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
