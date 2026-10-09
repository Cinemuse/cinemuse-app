import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/features/navigation/nav_providers.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

class AppNavbar extends ConsumerStatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onLogoutTap;
  final VoidCallback? onSearchTap;

  const AppNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onSettingsTap,
    this.onLogoutTap,
    this.onSearchTap,
  });

  @override
  ConsumerState<AppNavbar> createState() => _AppNavbarState();
}

class _AppNavbarState extends ConsumerState<AppNavbar> {
  final GlobalKey<PopupMenuButtonState<int>> _settingsMenuKey = GlobalKey();
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
        ref.read(topNavbarFocusActionProvider.notifier).state = () {
          _focusActiveItem();
        };
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
      if (index > 0) {
        _pillFocusNodes[index - 1].requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (index < _pillFocusNodes.length - 1) {
        _pillFocusNodes[index + 1].requestFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      final actions = ref.read(pageContentFocusActionsProvider);
      final currentAction = actions[widget.currentIndex];
      if (currentAction != null) {
        currentAction();
        return KeyEventResult.handled;
      }
      final fallbackAction = ref.read(pageContentFocusActionProvider);
      if (fallbackAction != null) {
        fallbackAction();
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
    final l10n = AppLocalizations.of(context)!;
    final isDesktop =
        Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    // Visual styling for the background
    final navbarDecoration = BoxDecoration(
      color: theme.colorScheme.surface,
      border: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
    );

    // Common padding for both layers to ensure alignment
    final padding = EdgeInsets.symmetric(
      horizontal: AppTheme.getResponsiveHorizontalPadding(context),
      vertical: 16,
    );

    // Dynamic top padding for mobile notches
    final topPadding = isDesktop
        ? 16.0
        : (MediaQuery.of(context).padding.top + 12.0);
    final mobilePadding = padding.copyWith(top: topPadding);

    return ClipRRect(
      child: isDesktop
          ? Stack(
              children: [
                // 1. Draggable Background Layer (Visuals + Drag)
                Positioned.fill(
                  child: DragToMoveArea(
                    child: Container(decoration: navbarDecoration),
                  ),
                ),

                // 2. Interaction Layer (Logo, Pill, Buttons)
                Container(
                  padding: padding,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Logo (Left)
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => widget.onTap(0),
                          child: Image.asset(
                            'assets/wordmark.png',
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),

                      // ... (rest of desktop layout remains the same)
                      // Unified Central Pill
                      if (isDesktop && MediaQuery.of(context).size.width >= 600)
                        Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _NavItem(
                                label: l10n.navHome,
                                isSelected: widget.currentIndex == 0,
                                onTap: () => widget.onTap(0),
                                focusNode: _pillFocusNodes[0],
                                onKeyEvent: (node, event) =>
                                    _handlePillKeyEvent(0, node, event),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                  bottomLeft: Radius.circular(20),
                                  topRight: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                              const SizedBox(width: 4),
                              _NavItem(
                                label: l10n.navExplore,
                                isSelected: widget.currentIndex == 1,
                                onTap: () => widget.onTap(1),
                                focusNode: _pillFocusNodes[1],
                                onKeyEvent: (node, event) =>
                                    _handlePillKeyEvent(1, node, event),
                              ),
                              const SizedBox(width: 4),
                              _NavItem(
                                label: l10n.navLiveTV,
                                isSelected: widget.currentIndex == 2,
                                onTap: () => widget.onTap(2),
                                focusNode: _pillFocusNodes[2],
                                onKeyEvent: (node, event) =>
                                    _handlePillKeyEvent(2, node, event),
                              ),
                              const SizedBox(width: 4),
                              _NavItem(
                                label: l10n.navLibrary,
                                isSelected: widget.currentIndex == 3,
                                onTap: () => widget.onTap(3),
                                focusNode: _pillFocusNodes[3],
                                onKeyEvent: (node, event) =>
                                    _handlePillKeyEvent(3, node, event),
                              ),
                              const _NavDivider(),
                              _IconAction(
                                icon: Icons.search,
                                onTap: () => widget.onSearchTap?.call(),
                                focusNode: _pillFocusNodes[4],
                                onKeyEvent: (node, event) =>
                                    _handlePillKeyEvent(4, node, event),
                              ),
                              const SizedBox(width: 4),
                              // Profile Icon / Settings Trigger
                              Focus(
                                focusNode: _pillFocusNodes[5],
                                onKeyEvent: (node, event) =>
                                    _handlePillKeyEvent(5, node, event),
                                onFocusChange: (focused) => setState(
                                  () => _isSettingsFocused = focused,
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    popupMenuTheme: PopupMenuThemeData(
                                      color: theme.colorScheme.surface,
                                      textStyle: TextStyle(
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: theme.colorScheme.onSurface
                                              .withValues(alpha: 0.1),
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: PopupMenuButton<int>(
                                    key: _settingsMenuKey,
                                    tooltip: l10n.settingsTitle,
                                    offset: const Offset(0, 48),
                                    constraints: const BoxConstraints(
                                      minWidth: 160,
                                    ),
                                    onSelected: (value) {
                                      if (value == -1) {
                                        widget.onSettingsTap?.call();
                                      } else if (value == -2) {
                                        widget.onLogoutTap?.call();
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: -1,
                                        height: 40,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.settings_outlined,
                                              size: 18,
                                              color: theme.colorScheme.onSurface
                                                  .withValues(alpha: 0.7),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(l10n.settingsTitle),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: -2,
                                        height: 40,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.logout_rounded,
                                              size: 18,
                                              color: Colors.redAccent,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              l10n.settingsLogout,
                                              style: const TextStyle(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => _settingsMenuKey
                                            .currentState
                                            ?.showButtonMenu(),
                                        mouseCursor: SystemMouseCursors.click,
                                        borderRadius: BorderRadius.circular(20),
                                        hoverColor: theme.hoverColor,
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 150,
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _isSettingsFocused
                                                ? theme.focusColor
                                                : Colors.transparent,
                                          ),
                                          child: Icon(
                                            Icons.person_rounded,
                                            color: _isSettingsFocused
                                                ? theme.colorScheme.onSurface
                                                : theme.colorScheme.onSurface
                                                      .withValues(alpha: 0.7),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                        ),

                      // Hidden placeholder on the right
                      if (isDesktop) const SizedBox(width: 120),
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
            )
          : Container(
              decoration: navbarDecoration,
              padding: mobilePadding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo (Left)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => widget.onTap(0),
                      child: Image.asset(
                        'assets/wordmark.png',
                        height: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Mobile Actions (Right)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _IconAction(
                        icon: Icons.search,
                        onTap: () => widget.onSearchTap?.call(),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Theme(
                        data: Theme.of(context).copyWith(
                          popupMenuTheme: PopupMenuThemeData(
                            color: theme.colorScheme.surface,
                            textStyle: TextStyle(
                              color: theme.colorScheme.onSurface,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        child: PopupMenuButton<int>(
                          icon: Icon(
                            Icons.person_rounded,
                            color: theme.colorScheme.onSurface,
                            size: 24,
                          ),
                          tooltip: l10n.settingsTitle,
                          offset: const Offset(0, 48),
                          constraints: const BoxConstraints(minWidth: 160),
                          onSelected: (value) {
                            if (value == -1) {
                              widget.onSettingsTap?.call();
                            } else if (value == -2) {
                              widget.onLogoutTap?.call();
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: -1,
                              height: 48, // Slightly larger for touch
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.settings_outlined,
                                    size: 20,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(l10n.settingsTitle),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: -2,
                              height: 48,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.logout_rounded,
                                    size: 20,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    l10n.settingsLogout,
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class AppWindowButtons extends StatefulWidget {
  const AppWindowButtons({super.key});

  @override
  State<AppWindowButtons> createState() => _AppWindowButtonsState();
}

class _AppWindowButtonsState extends State<AppWindowButtons>
    with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    final maximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() => _isMaximized = maximized);
    }
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WindowButton(
          type: _WindowButtonType.minimize,
          onTap: () => windowManager.minimize(),
        ),
        _WindowButton(
          type: _isMaximized
              ? _WindowButtonType.restore
              : _WindowButtonType.maximize,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
        _WindowButton(
          type: _WindowButtonType.close,
          onTap: () => windowManager.close(),
        ),
      ],
    );
  }
}

enum _WindowButtonType { minimize, maximize, restore, close }

class _WindowButton extends StatelessWidget {
  final _WindowButtonType type;
  final VoidCallback onTap;

  const _WindowButton({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isClose = type == _WindowButtonType.close;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: isClose
            ? const Color(0xFFE81123) // Standard close red
            : Colors.white.withValues(alpha: 0.1),
        child: SizedBox(
          width: 46, // Standard title bar button width
          child: Center(child: _buildIcon()),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (type) {
      case _WindowButtonType.minimize:
        return Container(width: 10, height: 1, color: Colors.white);
      case _WindowButtonType.maximize:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 1),
          ),
        );
      case _WindowButtonType.restore:
        return SizedBox(
          width: 10,
          height: 10,
          child: CustomPaint(painter: _RestoreIconPainter()),
        );
      case _WindowButtonType.close:
        return SizedBox(
          width: 10,
          height: 10,
          child: CustomPaint(painter: _CloseIconPainter()),
        );
    }
  }
}

class _RestoreIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Back square (offset top-right)
    canvas.drawRect(
      Rect.fromLTWH(2, 0, size.width - 2, size.height - 2),
      paint,
    );
    // Front square (bottom-left)
    canvas.drawRect(
      Rect.fromLTWH(0, 2, size.width - 2, size.height - 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CloseIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _NavItem extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final BorderRadius? borderRadius;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  const _NavItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.borderRadius,
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
    final effectiveRadius = widget.borderRadius ?? BorderRadius.circular(20);

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: widget.onKeyEvent,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
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
            child: Text(
              widget.label,
              style: TextStyle(
                color: (widget.isSelected || _isFocused)
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: (widget.isSelected || _isFocused)
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

class _IconAction extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final FocusNode? focusNode;
  final FocusOnKeyEventCallback? onKeyEvent;

  const _IconAction({
    required this.icon,
    required this.onTap,
    this.size = 20,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  State<_IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<_IconAction> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Focus(
      focusNode: widget.focusNode,
      onKeyEvent: widget.onKeyEvent,
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
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
              widget.icon,
              color: _isFocused
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              size: widget.size,
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
