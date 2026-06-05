import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/app_bottom_sheet.dart';

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
    Offset? position,
  }) async {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return _showBottomSheet(context, options, title);
    } else {
      return _showPopupMenu(context, options, anchorContext, position);
    }
  }

  static Future<void> _showBottomSheet(
    BuildContext context,
    List<AppMenuOption> options,
    String? title,
  ) {
    return AppBottomSheet.show(
      context: context,
      child: AppBottomSheet(
        blurSigma: 15.0,
        backgroundColor: AppTheme.primary.withValues(alpha: 0.8),
        border: Border.all(color: AppTheme.border, width: 0.5),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 16,
          top: 8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 24, right: 24),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ...options.map(
              (option) => ListTile(
                leading: Icon(
                  option.icon,
                  color: option.isDestructive
                      ? AppTheme.favorites
                      : Colors.white70,
                ),
                title: Text(
                  option.label,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: option.isDestructive
                        ? AppTheme.favorites
                        : Colors.white,
                    fontSize: 16,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  option.onTap();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _showPopupMenu(
    BuildContext context,
    List<AppMenuOption> options,
    BuildContext? anchorContext,
    Offset? position,
  ) {
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return Future.value();

    final RelativeRect relativePosition;

    if (position != null) {
      // Prioritize explicit position
      relativePosition = RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      );
    } else if (anchorContext != null) {
      // Anchor to the trigger widget
      final RenderBox button = anchorContext.findRenderObject() as RenderBox;
      final Offset buttonPosition = button.localToGlobal(
        Offset.zero,
        ancestor: overlay,
      );
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
          .map(
            (option) => PopupMenuItem(
              onTap: option.onTap,
              child: Row(
                children: [
                  Icon(
                    option.icon,
                    size: 18,
                    color: option.isDestructive
                        ? AppTheme.favorites
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          option.label,
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(
                                color: option.isDestructive
                                    ? AppTheme.favorites
                                    : Colors.white,
                                fontSize: 14,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (option.subtitle != null)
                          Text(
                            option.subtitle!,
                            style: Theme.of(context).textTheme.bodyMedium!
                                .copyWith(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
