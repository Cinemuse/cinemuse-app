import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';

class AppMenuOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final String? subtitle;

  const AppMenuOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.subtitle,
  });
}

class AppMenu {
  static Future<void> show({
    required BuildContext context,
    required List<AppMenuOption> options,
    String? title,
    BuildContext? anchorContext,
  }) async {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return _showBottomSheet(context, options, title);
    } else {
      return _showPopupMenu(context, options, anchorContext);
    }
  }

  static Future<void> _showBottomSheet(
    BuildContext context,
    List<AppMenuOption> options,
    String? title,
  ) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              top: 8,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.8),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppTheme.border, width: 0.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ...options.map((option) => ListTile(
                      leading: Icon(
                        option.icon,
                        color: option.isDestructive ? AppTheme.favorites : Colors.white70,
                      ),
                      title: Text(
                        option.label,
                        style: GoogleFonts.outfit(
                          color: option.isDestructive ? AppTheme.favorites : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        option.onTap();
                      },
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _showPopupMenu(
    BuildContext context,
    List<AppMenuOption> options,
    BuildContext? anchorContext,
  ) {
    final RenderBox? overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return Future.value();

    final RelativeRect relativePosition;

    if (anchorContext != null) {
      // Anchor to the trigger widget
      final RenderBox button = anchorContext.findRenderObject() as RenderBox;
      final Offset buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
      relativePosition = RelativeRect.fromLTRB(
        buttonPosition.dx,
        buttonPosition.dy + button.size.height,
        overlay.size.width - buttonPosition.dx - button.size.width,
        0,
      );
    } else {
      // Fallback to center if no anchor is provided
      relativePosition = RelativeRect.fromLTRB(
        overlay.size.width / 2,
        overlay.size.height / 2,
        overlay.size.width / 2,
        overlay.size.height / 2,
      );
    }

    return showMenu(
      context: context,
      position: relativePosition,
      color: AppTheme.surface.withValues(alpha: 0.95),
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border, width: 1),
      ),
      items: options
          .map((option) => PopupMenuItem(
                onTap: option.onTap,
                child: Row(
                  children: [
                    Icon(
                      option.icon,
                      size: 18,
                      color: option.isDestructive ? AppTheme.favorites : Colors.white.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          option.label,
                          style: GoogleFonts.outfit(
                            color: option.isDestructive ? AppTheme.favorites : Colors.white,
                            fontSize: 14,
                          ),
                        ),
                        if (option.subtitle != null)
                          Text(
                            option.subtitle!,
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}
