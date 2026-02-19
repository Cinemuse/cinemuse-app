import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class AppBottomNavbar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNavbar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // Check for safe area (especially bottom padding for modern phones)
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.8),
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 0.5,
              ),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: bottomPadding > 0 ? bottomPadding : 12,
            top: 12,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BottomNavItem(
                icon: currentIndex == 0 ? Icons.home : Icons.home_outlined,
                label: l10n.navHome,
                isSelected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _BottomNavItem(
                icon: currentIndex == 1 ? Icons.explore : Icons.explore_outlined,
                label: l10n.navExplore,
                isSelected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _BottomNavItem(
                icon: currentIndex == 2 ? Icons.live_tv : Icons.live_tv_outlined,
                label: "Live TV",
                isSelected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _BottomNavItem(
                icon: currentIndex == 3 ? Icons.video_library : Icons.video_library_outlined,
                label: l10n.navLibrary,
                isSelected: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accent.withOpacity(0.1) : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? AppTheme.accent : AppTheme.textMuted,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textMuted,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
