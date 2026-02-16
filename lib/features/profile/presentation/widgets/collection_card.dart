import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CollectionCard extends StatelessWidget {
  final UserList list;
  final VoidCallback onTap;

  const CollectionCard({
    super.key,
    required this.list,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine styling based on type
    final isWatchlist = list.type == ListType.watchlist;
    final isFavorites = list.type == ListType.favorites;

    Color borderColor = Colors.white10;
    double borderWidth = 1.0;
    Color iconColor = Colors.grey;
    Color badgeColor = Colors.grey;
    Color badgeBg = Colors.white10;
    IconData icon = LucideIcons.list;
    List<Color> backgroundGradient = [AppTheme.surface, AppTheme.surface];
    List<Color> headerGradient = [Colors.black.withOpacity(0.05), Colors.black.withOpacity(0.05)];

    if (isWatchlist) {
      borderColor = const Color(0xFFCA8A04).withOpacity(0.4); // yellow-600/40
      borderWidth = 2.0;
      iconColor = const Color(0xFFEAB308); // yellow-500
      badgeColor = const Color(0xFFEAB308); // yellow-500
      badgeBg = const Color(0xFFEAB308).withOpacity(0.2); // yellow-500/20
      icon = LucideIcons.bookmark;
      backgroundGradient = [
        const Color(0xFF713F12).withOpacity(0.3), // yellow-900/30
        const Color(0xFF7C2D12).withOpacity(0.2), // orange-900/20
      ];
      headerGradient = [
        const Color(0xFFCA8A04).withOpacity(0.2), // yellow-600/20
        const Color(0xFFEA580C).withOpacity(0.2), // orange-600/20
      ];
    } else if (isFavorites) {
      borderColor = const Color(0xFFDC2626).withOpacity(0.4); // red-600/40
      borderWidth = 2.0;
      iconColor = const Color(0xFFEF4444); // red-500
      badgeColor = const Color(0xFFEF4444); // red-500
      badgeBg = const Color(0xFFEF4444).withOpacity(0.2); // red-500/20
      icon = LucideIcons.heart;
      backgroundGradient = [
        const Color(0xFF7F1D1D).withOpacity(0.3), // red-900/30
        const Color(0xFF831843).withOpacity(0.2), // pink-900/20
      ];
      headerGradient = [
        const Color(0xFFDC2626).withOpacity(0.2), // red-600/20
        const Color(0xFFDB2777).withOpacity(0.2), // pink-600/20
      ];
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: backgroundGradient,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Image Grid (Top 3 items)
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  // Header Background Gradient (Fallback when empty)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: headerGradient,
                        ),
                      ),
                    ),
                  ),
                   if (list.items.isNotEmpty)
                    Row(
                      children: list.items.take(3).map((item) {
                        // Use poster_path from meta if available
                        final posterPath = item.meta['poster_path'] as String?;
                        return Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              border: Border(right: BorderSide(color: Colors.black12)),
                            ),
                            child: posterPath != null
                                ? CachedNetworkImage(
                                    imageUrl: 'https://image.tmdb.org/t/p/w200$posterPath',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    errorWidget: (_, __, ___) => Container(color: Colors.grey[900]),
                                  )
                                : Container(color: Colors.grey[900]),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Center(
                      child: Icon(icon, size: 32, color: iconColor.withOpacity(0.5)),
                    ),
                  
                  // Bottom Fade Gradient (matches web)
                   Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.4),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Body
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(16), // Increased padding to match web feel
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Title & Icon
                        Expanded(
                          child: Row(
                            children: [
                              Icon(icon, size: 18, color: iconColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  list.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Count Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${list.items.length}',
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      list.description ?? (list.items.isEmpty ? 'No items yet' : 'Click to view all items'),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

