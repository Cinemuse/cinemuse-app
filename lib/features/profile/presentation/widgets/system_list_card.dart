import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:flutter/material.dart';

class SystemListCard extends StatelessWidget {
  final UserList list;
  final VoidCallback onTap;

  const SystemListCard({
    super.key,
    required this.list,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isWatchlist = list.type == ListType.watchlist;
    
    final Color baseColor = isWatchlist ? AppTheme.watchlist : AppTheme.favorites;
    final Color iconBoxColor = isWatchlist ? AppTheme.watchlist.withOpacity(0.2) : AppTheme.favorites.withOpacity(0.2);
    final Color iconColor = isWatchlist ? AppTheme.watchlist : AppTheme.favorites;
    final IconData icon = isWatchlist ? Icons.bookmark : Icons.favorite;
    final String title = isWatchlist ? "Watch Later" : "Favorites";
    final String subtitle = isWatchlist ? "Your queue" : "Your curated picks";

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
              baseColor.withOpacity(0.8),
              baseColor.withOpacity(0.4),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBoxColor.withOpacity(0.3),
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
                      color: Colors.white.withOpacity(0.5),
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
