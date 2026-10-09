import 'package:flutter/material.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/external_links.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/gallery_box.dart';

/// A responsive row displaying Gallery and External Links
/// side-by-side with spatial navigation.
///
/// Automatically flexes into a 2-column or 1-column layout if any section is absent,
/// or stacks vertically on narrow viewports to avoid overflows.
class MediaInfoRow extends StatelessWidget {
  final MediaItem? mediaItem;
  final Map<String, dynamic>? details;
  final String typeForTmdb;
  final double spacing;

  const MediaInfoRow({
    super.key,
    this.mediaItem,
    this.details,
    required this.typeForTmdb,
    this.spacing = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final images = mediaItem?.images;
    final backdrops = images?.backdrops ?? (details?['images']?['backdrops'] as List?) ?? [];
    final posters = images?.posters ?? (details?['images']?['posters'] as List?) ?? [];
    final logos = images?.logos ?? (details?['images']?['logos'] as List?) ?? [];
    final hasGallery =
        backdrops.isNotEmpty || posters.isNotEmpty || logos.isNotEmpty;

    final extIds = mediaItem?.externalIds ??
        (details?['external_ids'] != null
            ? ExternalIds.fromTmdbMap(Map<String, dynamic>.from(details!['external_ids']))
            : null);
    final homepage = mediaItem?.homepage ?? (details?['homepage'] as String?);
    final hasLinks = extIds != null ||
        (homepage != null && homepage.trim().isNotEmpty);

    final columns = <Widget>[];

    if (hasGallery) {
      columns.add(GalleryBox(images: images, details: details));
    }

    if (hasLinks) {
      final tmdbId = mediaItem?.tmdbId ??
          (details?['id'] is int
              ? details!['id'] as int
              : int.tryParse(details?['id']?.toString() ?? '') ?? 0);

      columns.add(
        ExternalLinks(
          ids: extIds,
          homepage: homepage,
          type: typeForTmdb,
          tmdbId: tmdbId,
        ),
      );
    }

    if (columns.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;

        if (isNarrow) {
          return FocusTraversalGroup(
            policy: WidgetOrderTraversalPolicy(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < columns.length; i++) ...[
                  if (i > 0) SizedBox(height: spacing),
                  columns[i],
                ],
              ],
            ),
          );
        }

        return FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < columns.length; i++) ...[
                  if (i > 0) SizedBox(width: spacing),
                  Expanded(child: columns[i]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
