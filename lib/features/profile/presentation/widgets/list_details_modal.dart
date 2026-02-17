import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ListDetailsModal extends StatelessWidget {
  final UserList list;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ListDetailsModal({
    super.key,
    required this.list,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isSystemList = list.type == ListType.watchlist || list.type == ListType.favorites;
    final icon = list.type == ListType.watchlist 
        ? LucideIcons.bookmark 
        : (list.type == ListType.favorites ? LucideIcons.heart : LucideIcons.list);
    
    final iconColor = list.type == ListType.watchlist 
        ? AppTheme.watchlist 
        : (list.type == ListType.favorites ? AppTheme.favorites : Colors.white);

    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Colors.white10),
      ),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 1000,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: iconColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              list.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${list.items.length} items',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Actions
                      if (!isSystemList) ...[
                        IconButton(
                          onPressed: onEdit,
                          icon: const Icon(LucideIcons.edit3, size: 20, color: Colors.grey),
                          tooltip: 'Edit List',
                        ),
                        IconButton(
                          onPressed: onDelete,
                          icon: const Icon(LucideIcons.trash2, size: 20, color: Colors.redAccent),
                          tooltip: 'Delete List',
                        ),
                        const SizedBox(width: 8),
                      ],
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(LucideIcons.x, size: 24, color: Colors.white),
                      ),
                    ],
                  ),
                  if (list.description != null && list.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.only(left: 16),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: AppTheme.accent.withOpacity(0.5), width: 2),
                        ),
                      ),
                      child: Text(
                        list.description!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            const Divider(color: Colors.white10, height: 1),

            // Content
            Expanded(
              child: list.items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 64, color: iconColor.withOpacity(0.2)),
                          const SizedBox(height: 16),
                          const Text(
                            "This list is empty",
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Add media from the details page",
                            style: TextStyle(color: Colors.white.withOpacity(0.5)),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        childAspectRatio: 0.65,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: list.items.length,
                      itemBuilder: (context, index) {
                        final item = list.items[index];
                        final posterPath = item.meta['poster_path'] as String?;
                        final title = item.meta['title'] as String? ?? 'Unknown';
                        final rating = (item.meta['rating'] as num?)?.toDouble();
                        final year = item.meta['year']?.toString();

                        return MediaCard(
                          title: title,
                          posterPath: posterPath,
                          rating: rating,
                          releaseDate: year,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => MediaDetailsScreen(
                                  mediaId: item.tmdbId.toString(),
                                  mediaType: item.mediaType.name,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
