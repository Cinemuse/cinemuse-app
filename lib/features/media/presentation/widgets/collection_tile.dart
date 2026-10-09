import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/core/constants/tmdb_image_helper.dart';
import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/list_details_sheet.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/app_snackbar.dart';
import 'package:lucide_icons/lucide_icons.dart';

class CollectionTile extends ConsumerStatefulWidget {
  final MediaCollection collection;

  const CollectionTile({super.key, required this.collection});

  @override
  ConsumerState<CollectionTile> createState() => _CollectionTileState();
}

class _CollectionTileState extends ConsumerState<CollectionTile> {
  bool _isLoading = false;

  int get _collectionId => widget.collection.id;

  String _getTitle(AppLocalizations l10n) {
    return widget.collection.name.isNotEmpty
        ? widget.collection.name
        : l10n.collectionTitleFallback;
  }

  String? get _backdropPath => widget.collection.backdropPath;

  void _openCollection(BuildContext context, WidgetRef ref) async {
    if (_isLoading || _collectionId == 0) return;

    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
    });

    final model = await ref.read(collectionModelProvider(_collectionId).future);

    if (!context.mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (model != null) {
      final listItems = model.parts.map((mediaItem) {
        return UserListItem(
          listId: 'collection_$_collectionId',
          addedAt: DateTime.now(),
          tmdbId: mediaItem.tmdbId,
          mediaType: mediaItem.mediaType,
          media: mediaItem,
          meta: {},
        );
      }).toList();

      final userList = UserList(
        id: 'collection_$_collectionId',
        name: model.name.isNotEmpty ? model.name : _getTitle(l10n),
        description: model.overview,
        type: ListType.custom,
        items: listItems,
        createdAt: DateTime.now(),
        userId: 'system',
      );

      ListDetailsSheet.show(context, list: userList);
    } else {
      AppSnackBar.show(context, message: l10n.detailsFailedLoadCollection);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _getTitle(l10n);
    final backdropPath = _backdropPath;

    return GestureDetector(
      onTap: () => _openCollection(context, ref),
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: AppTheme.radiusLg,
          color: AppTheme.surface,
          image: backdropPath != null
              ? DecorationImage(
                  image: CachedNetworkImageProvider(
                    TmdbImageHelper.backdropCardUrl(context, backdropPath) ??
                        '',
                    maxWidth: 800,
                  ),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    AppTheme.primary.withValues(alpha: 0.6),
                    BlendMode.darken,
                  ),
                )
              : null,
          border: Border.all(color: AppTheme.textWhite.withValues(alpha: 0.05)),
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
                      borderRadius: AppTheme.radius12,
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
                            color: AppTheme.textWhite,
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
                            color: AppTheme.textWhite.withValues(alpha: 0.7),
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
