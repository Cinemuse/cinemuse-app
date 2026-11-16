import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/services/system/app_full_screen.dart';
import 'package:cinemuse_app/core/utils/platform_info.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/navigation/application/nav_providers.dart';
import 'package:cinemuse_app/features/updates/application/update_service.dart';
import 'package:cinemuse_app/features/navigation/presentation/window_buttons.dart';
import 'package:cinemuse_app/shared/widgets/focus_ring.dart';
import 'package:window_manager/window_manager.dart';

/// Top bar of the app shell.
///
/// [isCompact] comes from the shell (`Breakpoints.isCompact`), so the shell
/// and the navbar always agree on the layout (REV-51): wide windows get the
/// tab pill on every platform, narrow ones get logo + search + Settings
/// (the tabs are in the bottom bar then).
class AppNavbar extends ConsumerStatefulWidget {
  final int currentIndex;
  final bool isCompact;
  final ValueChanged<int> onTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onSearchTap;

  /// Down from the bar: focuses the page opened over the tabs (a title page,
  /// Settings) and returns true; false when no page is open.
  final bool Function()? onFocusOpenPage;

  const AppNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isCompact = false,
    this.onSettingsTap,
    this.onSearchTap,
    this.onFocusOpenPage,
  });

  @override
  ConsumerState<AppNavbar> createState() => _AppNavbarState();
}

class _AppNavbarState extends ConsumerState<AppNavbar> {
  late final List<FocusNode> _pillFocusNodes;

  @override
  void initState() {
    super.initState();
    _pillFocusNodes = List.generate(
      6,
      (index) => FocusNode(debugLabel: 'NavbarPill_$index'),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(topNavbarFocusActionProvider.notifier).set(_focusActiveItem);
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
      // The tab is hidden under an open page: Down goes back to the page.
      if (widget.onFocusOpenPage?.call() ?? false) {
        return KeyEventResult.handled;
      }
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
        widget.onSettingsTap?.call();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = PlatformInfo.isDesktop;
    // In full screen there is no window to drag, maximise or restore.
    final hasWindow = isDesktop && !ref.watch(appFullScreenProvider);
    final l10n = AppLocalizations.of(context)!;

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
                _NavIconButton(
                  icon: Icons.search,
                  tooltip: l10n.navSearch,
                  onTap: () => widget.onSearchTap?.call(),
                  size: 24,
                ),
                const SizedBox(width: 8),
                _NavIconButton(
                  icon: Icons.settings_outlined,
                  tooltip: l10n.settingsTitle,
                  onTap: () => widget.onSettingsTap?.call(),
                  showsDot: ref.watch(hasUpdateProvider),
                  size: 24,
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
            child: hasWindow
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
          if (hasWindow)
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
          _NavIconButton(
            icon: Icons.search,
            tooltip: l10n.navSearch,
            onTap: () => widget.onSearchTap?.call(),
            focusNode: _pillFocusNodes[4],
            onKeyEvent: (node, event) => _handlePillKeyEvent(4, node, event),
          ),
          const SizedBox(width: 4),
          _NavIconButton(
            icon: Icons.settings_outlined,
            tooltip: l10n.settingsTitle,
            onTap: () => widget.onSettingsTap?.call(),
            showsDot: ref.watch(hasUpdateProvider),
            focusNode: _pillFocusNodes[5],
            onKeyEvent: (node, event) => _handlePillKeyEvent(5, node, event),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

/// Round icon button of the top bar (search, Settings).
class _RoundNavIcon extends StatelessWidget {
  final IconData icon;
  final bool isFocused;
  final VoidCallback onTap;
  final double size;

  /// A new version is out (on Settings).
  final bool showsDot;

  const _RoundNavIcon({
    required this.icon,
    required this.isFocused,
    required this.onTap,
    this.size = 20,
    this.showsDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return FocusRing(
      isVisible: isFocused,
      borderRadius: AppTheme.radiusFull,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          // A Focus around it is the only Tab stop (REV-57).
          canRequestFocus: false,
          onTap: onTap,
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
            child: Badge(
              isLabelVisible: showsDot,
              backgroundColor: AppTheme.accent,
              smallSize: 8,
              child: Icon(
                icon,
                color: isFocused ? onSurface : onSurface.withValues(alpha: 0.7),
                size: size,
              ),
            ),
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
      // Painted outside: shows on the active tab, never resizes (REV-249/250).
      child: FocusRing(
        isVisible: _isFocused,
        borderRadius: effectiveRadius,
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
            // The highlight goes with the ring.
            child: ValueListenableBuilder(
              valueListenable: FocusRing.isKeyInput,
              builder: (context, isKeyInput, _) {
                final showsFocus = _isFocused && isKeyInput;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: widget.isSelected
                        ? AppTheme.accentSelectedBg
                        : (showsFocus ? theme.focusColor : Colors.transparent),
                    borderRadius: effectiveRadius,
                    border: Border.all(
                      color: widget.isSelected
                          ? AppTheme.accentSelectedBorder
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: (widget.isSelected || showsFocus)
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      // Not bold on focus: wider text made the bar move
                      // (REV-250).
                      fontWeight: widget.isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The top bar's round button with its tooltip: search, Settings.
class _NavIconButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final bool showsDot;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  const _NavIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 20,
    this.showsDot = false,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  State<_NavIconButton> createState() => _NavIconButtonState();
}

class _NavIconButtonState extends State<_NavIconButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: widget.onKeyEvent,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: Tooltip(
        message: widget.tooltip,
        // The highlight goes with the ring.
        child: ValueListenableBuilder(
          valueListenable: FocusRing.isKeyInput,
          builder: (context, isKeyInput, _) => _RoundNavIcon(
            icon: widget.icon,
            isFocused: _isFocused && isKeyInput,
            onTap: widget.onTap,
            size: widget.size,
            showsDot: widget.showsDot,
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
