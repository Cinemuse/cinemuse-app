import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/shared/widgets/carousels/poster_carousel_row.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart'; // for CarouselTheme
import 'package:cinemuse_app/l10n/app_localizations.dart';

class MediaRow extends ConsumerWidget {
  final String title;
  final AsyncValue<List<Map<String, dynamic>>> asyncData;
  final bool skipFirst;

  const MediaRow({
    super.key,
    required this.title,
    required this.asyncData,
    this.skipFirst = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (asyncData.hasError && !asyncData.hasValue) {
      final mapped = ref.read(errorMapperProvider).map(asyncData.error!);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(context),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.getResponsiveHorizontalPadding(context),
            ),
            child: ErrorCard(
              message: mapped.message,
              hint: mapped.hint,
              type: mapped.type,
            ),
          ),
        ],
      );
    }

    if (asyncData.isLoading && !asyncData.hasValue) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(context),
          const SizedBox(
            height: 356,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    final data = asyncData.value ?? [];
    final list = skipFirst && data.isNotEmpty ? data.skip(1).toList() : data;

    if (list.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(context),
          SizedBox(
            height: 356,
            child: Center(
              child: Text(
                AppLocalizations.of(context)!.commonNoContent,
                style: const TextStyle(color: Colors.white54),
              ),
            ),
          ),
        ],
      );
    }

    final mediaItems = list.map((item) {
      return MediaItem(
        tmdbId: item['id'] as int,
        mediaType:
            (item['media_type'] == 'tv' ||
                item['first_air_date'] != null ||
                item['name'] != null)
            ? MediaKind.tv
            : MediaKind.movie,
        titleEn: item['title'] ?? item['name'] ?? 'Unknown',
        posterPath: item['poster_path'],
        backdropPath: item['backdrop_path'],
        releaseDate: DateTime.tryParse(
          item['release_date'] ?? item['first_air_date'] ?? '',
        ),
        voteAverage: (item['vote_average'] as num?)?.toDouble(),
        updatedAt: item['updated_at'] != null
            ? DateTime.parse(item['updated_at'])
            : DateTime(2000), // Stable dummy
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
      theme: CarouselTheme.homeRow,
      items: cards,
      height: 356,
      itemWidth: 200,
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.getResponsiveHorizontalPadding(context),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.getResponsiveHorizontalPadding(context),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, color: AppTheme.textMuted),
        ],
      ),
    );
  }
}
