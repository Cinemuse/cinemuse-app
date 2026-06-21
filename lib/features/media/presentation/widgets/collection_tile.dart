import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/list_details_sheet.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CollectionTile extends ConsumerStatefulWidget {
  final Map<String, dynamic> collection;

  const CollectionTile({super.key, required this.collection});

  @override
  ConsumerState<CollectionTile> createState() => _CollectionTileState();
}

class _CollectionTileState extends ConsumerState<CollectionTile> {
  bool _isLoading = false;

  void _openCollection(BuildContext context, WidgetRef ref) async {
    if (_isLoading) return;

    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
    });

    final collectionId = widget.collection['id'] as int;
    final collectionData = await ref.read(
      collectionDetailsProvider(collectionId).future,
    );

    if (!context.mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (collectionData != null) {
      final parts = collectionData['parts'] as List<dynamic>? ?? [];

      final listItems = parts.map((part) {
        final itemMap = part as Map<String, dynamic>;
        final mediaItem = MediaItem(
          tmdbId: itemMap['id'] as int,
          mediaType: MediaKind.movie, // Collections are only for movies
          titleEn: itemMap['title'] ?? itemMap['name'] ?? l10n.commonUnknown,
          posterPath: itemMap['poster_path'],
          backdropPath: itemMap['backdrop_path'],
          releaseDate: DateTime.tryParse(itemMap['release_date'] ?? ''),
          voteAverage: (itemMap['vote_average'] as num?)?.toDouble(),
          updatedAt: DateTime.now(),
        );

        return UserListItem(
          listId: 'collection_$collectionId',
          addedAt: DateTime.now(),
          tmdbId: mediaItem.tmdbId,
          mediaType: mediaItem.mediaType,
          media: mediaItem,
          meta: {},
        );
      }).toList();

      final userList = UserList(
        id: 'collection_$collectionId',
        name:
            collectionData['name'] ??
            widget.collection['name'] ??
            l10n.collectionTitleFallback,
        description: collectionData['overview'],
        type: ListType.custom,
        items: listItems,
        createdAt: DateTime.now(),
        userId: 'system',
      );

      ListDetailsSheet.show(context, list: userList);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.detailsFailedLoadCollection)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.collection['name'] ?? l10n.collectionTitleFallback;
    final backdropPath = widget.collection['backdrop_path'];

    return GestureDetector(
      onTap: () => _openCollection(context, ref),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.surface,
          image: backdropPath != null
              ? DecorationImage(
                  image: NetworkImage(
                    TmdbImageHelper.backdropCardUrl(context, backdropPath)!,
                  ),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.6),
                    BlendMode.darken,
                  ),
                )
              : null,
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.film,
                      color: AppTheme.accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.collectionSubtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(color: AppTheme.accent),
              ),
          ],
        ),
      ),
    );
  }
}
