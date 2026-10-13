import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/utils/platform_info.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/navigation/presentation/window_buttons.dart';
import 'package:window_manager/window_manager.dart';

/// Top bar of the app shell.
///
/// [isCompact] comes from the shell (`Breakpoints.isCompact`), so the shell
/// and the navbar always agree on the layout (REV-51): wide windows get the
/// tab pill on every platform, narrow ones get logo + search + profile menu
/// (the tabs are in the bottom bar then).
class AppNavbar extends ConsumerStatefulWidget {
  final int currentIndex;
  final bool isCompact;
  final ValueChanged<int> onTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onLogoutTap;
  final VoidCallback? onSearchTap;

  const AppNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isCompact = false,
    this.onSettingsTap,
    this.onLogoutTap,
    this.onSearchTap,
  });

  @override
  ConsumerState<AppNavbar> createState() => _AppNavbarState();
}

class _AppNavbarState extends ConsumerState<AppNavbar> {
  final GlobalKey<PopupMenuButtonState<_ProfileAction>> _settingsMenuKey =
      GlobalKey();
  late final List<FocusNode> _pillFocusNodes;
  bool _isSettingsFocused = false;

  @override
  void initState() {
    super.initState();
    _pillFocusNodes = List.generate(
      6,
      (index) => FocusNode(debugLabel: 'NavbarPill_$index'),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(topNavbarFocusActionProvider.notifier).state =
            _focusActiveItem;
      }
    });
  }

  @override
  void dispose() {
    for (final node in _pillFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _focusActiveItem() {
    // The provider keeps this callback after the navbar is removed (Live TV
    // full window), and `ref` can't be used in dispose() to clear it (REV-55).
    if (!mounted) return;
    final targetIndex = widget.currentIndex.clamp(0, 3);
    if (targetIndex >= 0 && targetIndex < _pillFocusNodes.length) {
      _pillFocusNodes[targetIndex].requestFocus();
    }
  }

  KeyEventResult _handlePillKeyEvent(
    int index,
    FocusNode node,
    KeyEvent event,
  ) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (index > 0) _pillFocusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _pillFocusNodes.elementAtOrNull(index + 1)?.requestFocus();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final actions = ref.read(pageContentFocusActionsProvider);
      final currentAction = actions[widget.currentIndex];
      if (currentAction != null) {
        currentAction();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      return KeyEventResult.handled;
    }

    final isActivationKey =
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter ||
        event.logicalKey == LogicalKeyboardKey.select ||
        event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.gameButtonA;

    if (isActivationKey) {
      if (index >= 0 && index <= 3) {
        widget.onTap(index);
        return KeyEventResult.handled;
      } else if (index == 4) {
        widget.onSearchTap?.call();
        return KeyEventResult.handled;
      } else if (index == 5) {
        _settingsMenuKey.currentState?.showButtonMenu();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = PlatformInfo.isDesktop;

    final navbarDecoration = BoxDecoration(
      color: theme.colorScheme.surface,
      border: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
    );

    // On phones and tablets, keep clear of the status bar / notch.
    final padding = EdgeInsets.fromLTRB(
      AppTheme.getResponsiveHorizontalPadding(context),
      isDesktop ? 16 : MediaQuery.paddingOf(context).top + 12,
      AppTheme.getResponsiveHorizontalPadding(context),
      16,
    );

    final logo = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => widget.onTap(0),
        child: Image.asset('assets/wordmark.png', height: 32),
      ),
    );

    if (widget.isCompact) {
      return Container(
        decoration: navbarDecoration,
        padding: padding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            logo,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SearchButton(
                  onTap: () => widget.onSearchTap?.call(),
                  size: 24,
                ),
                const SizedBox(width: 8),
                _ProfileMenu(
                  isCompact: true,
                  onSettingsTap: widget.onSettingsTap,
                  onLogoutTap: widget.onLogoutTap,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      child: Stack(
        children: [
          // Background; on desktop it also drags the frameless window.
          Positioned.fill(
            child: isDesktop
                ? DragToMoveArea(child: Container(decoration: navbarDecoration))
                : DecoratedBox(decoration: navbarDecoration),
          ),
          Container(
            padding: padding,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                logo,
                _buildPill(theme),
                // Balances the logo so the pill stays near the centre, and
                // leaves room for the window buttons on desktop.
                const SizedBox(width: 120),
              ],
            ),
          ),
          if (isDesktop)
            const Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: AppWindowButtons(),
            ),
        ],
      ),
    );
  }

  Widget _buildPill(ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    final tabLabels = [
      l10n.navHome,
      l10n.navExplore,
      l10n.navLiveTV,
      l10n.navLibrary,
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < tabLabels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            _NavItem(
              label: tabLabels[i],
              isSelected: widget.currentIndex == i,
              onTap: () => widget.onTap(i),
              focusNode: _pillFocusNodes[i],
              onKeyEvent: (node, event) => _handlePillKeyEvent(i, node, event),
            ),
          ],
          const _NavDivider(),
          _SearchButton(
            onTap: () => widget.onSearchTap?.call(),
            focusNode: _pillFocusNodes[4],
            onKeyEvent: (node, event) => _handlePillKeyEvent(4, node, event),
          ),
          const SizedBox(width: 4),
          Focus(
            focusNode: _pillFocusNodes[5],
            onKeyEvent: (node, event) => _handlePillKeyEvent(5, node, event),
            onFocusChange: (focused) =>
                setState(() => _isSettingsFocused = focused),
            // The menu button's own InkWell would be a second Tab stop with
            // no highlight; this Focus already opens it on Enter (REV-57).
            child: ExcludeFocus(
              child: _ProfileMenu(
                menuKey: _settingsMenuKey,
                isCompact: false,
                isFocused: _isSettingsFocused,
                onSettingsTap: widget.onSettingsTap,
                onLogoutTap: widget.onLogoutTap,
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

enum _ProfileAction { settings, logout }

/// Profile icon that opens the Settings / Log out menu.
class _ProfileMenu extends StatelessWidget {
  final GlobalKey<PopupMenuButtonState<_ProfileAction>>? menuKey;
  final bool isCompact;
  final bool isFocused;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onLogoutTap;

  const _ProfileMenu({
    required this.isCompact,
    this.menuKey,
    this.isFocused = false,
    this.onSettingsTap,
    this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final onSurface = theme.colorScheme.onSurface;

    return Theme(
      data: theme.copyWith(
        popupMenuTheme: PopupMenuThemeData(
          color: theme.colorScheme.surface,
          textStyle: TextStyle(color: onSurface),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: onSurface.withValues(alpha: 0.1)),
          ),
        ),
      ),
      child: PopupMenuButton<_ProfileAction>(
        key: menuKey,
        tooltip: l10n.settingsTitle,
        offset: const Offset(0, 48),
        constraints: const BoxConstraints(minWidth: 160),
        onSelected: (action) => switch (action) {
          _ProfileAction.settings => onSettingsTap?.call(),
          _ProfileAction.logout => onLogoutTap?.call(),
        },
        itemBuilder: (context) => [
          _buildItem(
            _ProfileAction.settings,
            Icons.settings_outlined,
            l10n.settingsTitle,
            iconColor: onSurface.withValues(alpha: 0.7),
          ),
          _buildItem(
            _ProfileAction.logout,
            Icons.logout_rounded,
            l10n.settingsLogout,
            iconColor: Colors.redAccent,
            textColor: Colors.redAccent,
          ),
        ],
        icon: isCompact
            ? Icon(Icons.person_rounded, color: onSurface, size: 24)
            : null,
        child: isCompact ? null : _buildDesktopButton(theme),
      ),
    );
  }

  PopupMenuItem<_ProfileAction> _buildItem(
    _ProfileAction action,
    IconData icon,
    String label, {
    required Color iconColor,
    Color? textColor,
  }) {
    return PopupMenuItem(
      value: action,
      // Taller rows on touch screens.
      height: isCompact ? 48 : 40,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: isCompact ? 20 : 18, color: iconColor),
          SizedBox(width: isCompact ? 12 : 8),
          Text(
            label,
            style: textColor == null ? null : TextStyle(color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopButton(ThemeData theme) {
    final onSurface = theme.colorScheme.onSurface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => menuKey?.currentState?.showButtonMenu(),
        mouseCursor: SystemMouseCursors.click,
        borderRadius: BorderRadius.circular(20),
        hoverColor: theme.hoverColor,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFocused ? theme.focusColor : Colors.transparent,
          ),
          child: Icon(
            Icons.person_rounded,
            color: isFocused ? onSurface : onSurface.withValues(alpha: 0.7),
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  const _NavItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveRadius = BorderRadius.circular(20);

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: widget.onKeyEvent,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // The Focus above is the only Tab stop (REV-57).
          canRequestFocus: false,
          onTap: widget.onTap,
          borderRadius: effectiveRadius,
          mouseCursor: SystemMouseCursors.click,
          hoverColor: theme.hoverColor,
          focusColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.25)
                  : (_isFocused ? theme.focusColor : Colors.transparent),
              borderRadius: effectiveRadius,
              border: Border.all(
                color: widget.isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.5)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            // On top: shows on the active tab, never resizes it (REV-249/250).
            foregroundDecoration: _isFocused
                ? BoxDecoration(
                    borderRadius: effectiveRadius,
                    border: Border.all(color: AppTheme.focusRing, width: 2),
                    boxShadow: AppTheme.shadowFocusGlow,
                  )
                : null,
            child: Text(
              widget.label,
              style: TextStyle(
                color: (widget.isSelected || _isFocused)
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                // Not bold on focus: wider text made the bar move (REV-250).
                fontWeight: widget.isSelected
                    ? FontWeight.bold
                    : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  const _SearchButton({
    required this.onTap,
    this.size = 20,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  State<_SearchButton> createState() => _SearchButtonState();
}

class _SearchButtonState extends State<_SearchButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: widget.onKeyEvent,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: Tooltip(
        message: AppLocalizations.of(context)!.navSearch,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // The Focus above is the only Tab stop (REV-57).
            canRequestFocus: false,
            mouseCursor: SystemMouseCursors.click,
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            hoverColor: theme.hoverColor,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isFocused ? theme.focusColor : Colors.transparent,
              ),
              child: Icon(
                Icons.search,
                color: _isFocused
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                size: widget.size,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavDivider extends StatelessWidget {
  const _NavDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}
