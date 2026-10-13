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
  final MediaItem mediaItem;
  final String typeForTmdb;
  final double spacing;

  const MediaInfoRow({
    super.key,
    required this.mediaItem,
    required this.typeForTmdb,
    this.spacing = 24.0,
  });

  @override
  Widget build(BuildContext context) {
    final images = mediaItem.images;
    final hasGallery =
        images != null &&
        (images.backdrops.isNotEmpty ||
            images.posters.isNotEmpty ||
            images.logos.isNotEmpty);

    final extIds = mediaItem.externalIds;
    final homepage = mediaItem.homepage;
    final hasLinks =
        extIds != null || (homepage != null && homepage.trim().isNotEmpty);

    final columns = <Widget>[];

    if (hasGallery) {
      columns.add(GalleryBox(images: images));
    }

    if (hasLinks) {
      columns.add(
        ExternalLinks(
          ids: extIds,
          homepage: homepage,
          type: typeForTmdb,
          tmdbId: mediaItem.tmdbId,
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
