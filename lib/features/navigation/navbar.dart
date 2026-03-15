import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';

class AppNavbar extends StatefulWidget {
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
  State<AppNavbar> createState() => _AppNavbarState();
}

class _AppNavbarState extends State<AppNavbar> {
  final GlobalKey<PopupMenuButtonState<int>> _settingsMenuKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    // Visual styling for the background
    final navbarDecoration = BoxDecoration(
      color: AppTheme.surface.withOpacity(0.8),
      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
    );

    // Common padding for both layers to ensure alignment
    final padding = EdgeInsets.symmetric(
      horizontal: AppTheme.getResponsiveHorizontalPadding(context), 
      vertical: 16
    );

    return ClipRRect(
      child: isDesktop 
        ? Stack(
            children: [
              // 1. Draggable Background Layer (Visuals + Drag)
              Positioned.fill(
                child: DragToMoveArea(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(decoration: navbarDecoration),
                  ),
                ),
              ),
              
              // 2. Interaction Layer (Logo, Pill, Buttons)
              // We use a Container with transparent color to ensure it occupies the right size
              // but doesn't block hits in empty spaces (since Row doesn't have a background).
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

                    // Unified Central Pill
                    if (isDesktop && MediaQuery.of(context).size.width >= 600)
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.surface.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _NavItem(
                              label: l10n.navHome,
                              isSelected: widget.currentIndex == 0,
                              onTap: () => widget.onTap(0),
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
                            ),
                            const SizedBox(width: 4),
                            _NavItem(
                              label: "Live TV",
                              isSelected: widget.currentIndex == 2,
                              onTap: () => widget.onTap(2),
                            ),
                            const SizedBox(width: 4),
                            _NavItem(
                              label: l10n.navLibrary,
                              isSelected: widget.currentIndex == 3,
                              onTap: () => widget.onTap(3),
                            ),
                            const _NavDivider(),
                            _IconAction(
                              icon: Icons.search,
                              onTap: () => widget.onSearchTap?.call(),
                            ),
                            const SizedBox(width: 4),
                            // Profile Icon / Settings Trigger
                            Theme(
                              data: Theme.of(context).copyWith(
                                popupMenuTheme: PopupMenuThemeData(
                                  color: AppTheme.surface,
                                  textStyle: const TextStyle(color: Colors.white),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                  ),
                                ),
                              ),
                              child: PopupMenuButton<int>(
                                key: _settingsMenuKey,
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
                                    height: 40,
                                    child: Center(child: Text(l10n.settingsTitle)),
                                  ),
                                  PopupMenuItem(
                                    value: -2,
                                    height: 40,
                                    child: Center(
                                      child: Text(
                                        l10n.settingsLogout,
                                        style: const TextStyle(color: Colors.redAccent),
                                      ),
                                    ),
                                  ),
                                ],
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => _settingsMenuKey.currentState?.showButtonMenu(),
                                    mouseCursor: SystemMouseCursors.click,
                                    borderRadius: BorderRadius.circular(20),
                                    hoverColor: Colors.white.withOpacity(0.1),
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.person_rounded, 
                                        color: Colors.white, 
                                        size: 20
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

              if (Platform.isWindows)
                const Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: _WindowButtons(),
                ),
            ],
          )
        : BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: navbarDecoration,
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

                  // Mobile/Tablet Nav items could go here if needed, but AppShell handles index
                ],
              ),
            ),
          ),
    );
  }
}

class _WindowButtons extends StatelessWidget {
  const _WindowButtons();

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
          type: _WindowButtonType.maximize,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              windowManager.unmaximize();
            } else {
              windowManager.maximize();
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

enum _WindowButtonType { minimize, maximize, close }

class _WindowButton extends StatelessWidget {
  final _WindowButtonType type;
  final VoidCallback onTap;

  const _WindowButton({
    required this.type,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isClose = type == _WindowButtonType.close;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: isClose 
            ? const Color(0xFFE81123) // Standard Windows close red
            : Colors.white.withOpacity(0.1),
        child: SizedBox(
          width: 46, // Standard Windows title bar button width
          child: Center(
            child: _buildIcon(),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    switch (type) {
      case _WindowButtonType.minimize:
        return Container(
          width: 10,
          height: 1,
          color: Colors.white,
        );
      case _WindowButtonType.maximize:
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 1),
          ),
        );
      case _WindowButtonType.close:
        return SizedBox(
          width: 10,
          height: 10,
          child: CustomPaint(
            painter: _CloseIconPainter(),
          ),
        );
    }
  }
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

class _NavItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final BorderRadius? borderRadius;

  const _NavItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(20);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: effectiveRadius,
        mouseCursor: SystemMouseCursors.click,
        hoverColor: AppTheme.accent.withOpacity(0.1),
        focusColor: AppTheme.accent.withOpacity(0.2),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withOpacity(0.2) : Colors.transparent,
            borderRadius: effectiveRadius,
            border: Border.all(
              color: isSelected ? AppTheme.accent.withOpacity(0.5) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : AppTheme.textMuted,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        hoverColor: Colors.white.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: Colors.white, size: 20),
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
      color: Colors.white.withOpacity(0.1),
    );
  }
}
