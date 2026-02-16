import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class AppNavbar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    // Determine if we are using the local or synthetic package
    // Dynamic lookup to avoid build errors during transition if needed, 
    // but we use the imported AppLocalizations for now.
    final l10n = AppLocalizations.of(context)!;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.8),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: AppTheme.getResponsiveHorizontalPadding(context), 
            vertical: 16
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => onTap(0), // Go to home on logo click
                  child: Image.asset(
                    'assets/wordmark.png',
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Nav Items (Centered Pill)
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NavItem(
                      label: l10n.navHome,
                      isSelected: currentIndex == 0,
                      onTap: () => onTap(0),
                    ),
                    const SizedBox(width: 4),
                    _NavItem(
                      label: l10n.navExplore, // Explore
                      isSelected: currentIndex == 1,
                      onTap: () => onTap(1),
                    ),
                    const SizedBox(width: 4),
                    _NavItem(
                      label: "Live TV", // TODO: Add to localizations
                      isSelected: currentIndex == 2,
                      onTap: () => onTap(2),
                    ),
                    const SizedBox(width: 4),
                    _NavItem(
                      label: l10n.navLibrary, // Profile/Library
                      isSelected: currentIndex == 3,
                      onTap: () => onTap(3),
                    ),
                  ],
                ),
              ),

              // Actions (Right)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconAction(
                    icon: Icons.search,
                    onTap: () => onSearchTap?.call(), 
                  ),
                  const SizedBox(width: 16),
                  // Profile / Settings Trigger
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
                      tooltip: l10n.settingsProfile,
                      offset: const Offset(0, 48),
                      icon: const Icon(Icons.person_outline, color: AppTheme.textMuted, size: 24),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 3,
                          child: Row(
                            children: [
                              const Icon(Icons.person, size: 20, color: AppTheme.textMuted),
                              const SizedBox(width: 12),
                              Text(l10n.settingsProfile),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: -1,
                          child: Row(
                            children: [
                              const Icon(Icons.settings, size: 20, color: AppTheme.textMuted),
                              const SizedBox(width: 12),
                              Text(l10n.settingsTitle),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: -2,
                          child: Row(
                            children: [
                              const Icon(Icons.logout, size: 20, color: Colors.redAccent),
                              const SizedBox(width: 12),
                              Text(l10n.settingsLogout, style: const TextStyle(color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 3) {
                          onTap(3);
                        } else if (value == -1) {
                          onSettingsTap?.call();
                        } else if (value == -2) {
                          onLogoutTap?.call();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        mouseCursor: SystemMouseCursors.click,
        hoverColor: AppTheme.accent.withOpacity(0.1),
        focusColor: AppTheme.accent.withOpacity(0.2),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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
          child: Icon(icon, color: AppTheme.textMuted, size: 24),
        ),
      ),
    );
  }
}
