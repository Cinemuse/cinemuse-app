import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:flutter/material.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class SystemListCard extends StatelessWidget {
  final UserList list;
  final VoidCallback onTap;

  const SystemListCard({super.key, required this.list, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    final isWatchlist = list.type == ListType.watchlist;
    final isFavorites = list.type == ListType.favorites;


    final Color baseColor = isWatchlist
        ? AppTheme.watchlist
        : isFavorites
            ? AppTheme.favorites
            : Colors.grey.shade700;
            
    final Color iconBoxColor = isWatchlist
        ? AppTheme.watchlist.withValues(alpha: 0.2)
        : isFavorites
            ? AppTheme.favorites.withValues(alpha: 0.2)
            : Colors.grey.shade700.withValues(alpha: 0.2);
            
    final Color iconColor = isWatchlist
        ? AppTheme.watchlist
        : isFavorites
            ? AppTheme.favorites
            : Colors.grey.shade400;
            
    final IconData icon = isWatchlist 
        ? Icons.bookmark 
        : isFavorites 
            ? Icons.favorite 
            : Icons.do_not_disturb_alt;
            
    final String title = isWatchlist 
        ? l10n.listWatchLater 
        : isFavorites 
            ? l10n.listFavorites 
            : l10n.listDropped;
            
    final String subtitle = isWatchlist 
        ? l10n.listYourQueue 
        : isFavorites 
            ? l10n.listCuratedPicks 
            : l10n.listDroppedSubtitle;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              baseColor.withValues(alpha: 0.8),
              baseColor.withValues(alpha: 0.4),
            ],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBoxColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Count
            Text(
              '${list.items.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
