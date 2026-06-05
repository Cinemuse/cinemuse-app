import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/shared/widgets/carousels/poster_carousel_row.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';

class MediaListRow extends ConsumerWidget {
  final String title;
  final List<dynamic> items;
  final EdgeInsets? padding;
  final IconData? icon;
  final CarouselTheme theme;

  const MediaListRow({
    super.key,
    required this.title,
    required this.items,
    this.padding,
    this.icon,
    this.theme = CarouselTheme.homeRow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final mediaItems = items.map((item) {
      final mapItem = item as Map<String, dynamic>;
      return MediaItem(
        tmdbId: mapItem['id'] as int,
        mediaType:
            (mapItem['media_type'] == 'tv' ||
                mapItem['first_air_date'] != null ||
                mapItem['name'] != null)
            ? MediaKind.tv
            : MediaKind.movie,
        titleEn: mapItem['title'] ?? mapItem['name'] ?? 'Unknown',
        posterPath: mapItem['poster_path'],
        backdropPath: mapItem['backdrop_path'],
        releaseDate: DateTime.tryParse(
          mapItem['release_date'] ?? mapItem['first_air_date'] ?? '',
        ),
        voteAverage: (mapItem['vote_average'] as num?)?.toDouble(),
        updatedAt: DateTime.now(),
      );
    }).toList();

    final appLanguage = ref.watch(settingsProvider).appLanguage;

    final cards = mediaItems.map((item) {
      return MediaCard(
        title: item.getLocalizedTitle(appLanguage) ?? 'Unknown',
        posterPath: item.posterPath,
        releaseDate: item.releaseDate?.year.toString(),
        rating: item.voteAverage,
        tmdbId: item.tmdbId,
        mediaType: item.mediaType,
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
        onPlay: () {
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(
                queryId: item.tmdbId.toString(),
                type: item.mediaType.name,
              ),
            ),
          );
        },
      );
    }).toList();

    return PosterCarouselRow(
      title: title,
      icon: icon,
      theme: theme,
      items: cards,
      height: 356,
      itemWidth: 200,
      padding:
          padding ??
          (theme == CarouselTheme.bentoBox
              ? EdgeInsets.zero
              : EdgeInsets.symmetric(
                  horizontal: AppTheme.getResponsiveHorizontalPadding(context),
                )),
    );
  }
}
