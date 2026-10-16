import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/shared/widgets/error_card.dart';
import 'package:cinemuse_app/core/error/error_mappers.dart';
import 'package:cinemuse_app/shared/widgets/carousels/poster_carousel_row.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/title_list_actions.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart'; // for CarouselTheme
import 'package:cinemuse_app/shared/widgets/carousels/carousel_layout_calculator.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';

class MediaRow extends ConsumerWidget {
  final String title;
  final AsyncValue<List<MediaItem>> asyncData;
  final bool skipFirst;
  final VoidCallback? onHeaderTap;
  final int? limit;

  const MediaRow({
    super.key,
    required this.title,
    required this.asyncData,
    this.skipFirst = false,
    this.onHeaderTap,
    this.limit = 20,
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
            child: ErrorCard(error: mapped),
          ),
        ],
      );
    }

    final dimensions = CarouselLayoutCalculator.getPosterDimensions(context);

    if (asyncData.isLoading && !asyncData.hasValue) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(context),
          SizedBox(
            height: dimensions.height,
            child: const Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    final data = asyncData.value ?? [];
    var list = skipFirst && data.isNotEmpty ? data.skip(1).toList() : data;
    if (limit != null && list.length > limit!) {
      list = list.take(limit!).toList();
    }

    final l10n = AppLocalizations.of(context)!;

    if (list.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle(context),
          SizedBox(
            height: dimensions.height,
            child: Center(
              child: Text(
                l10n.commonNoContent,
                style: const TextStyle(color: AppTheme.textMuted),
              ),
            ),
          ),
        ],
      );
    }

    final mediaItems = list;

    final appLanguage = ref.watch(
      settingsProvider.select((s) => s.appLanguage),
    );

    final cards = mediaItems.map((item) {
      return MediaCard(
        title: item.getLocalizedTitle(appLanguage) ?? l10n.commonUnknown,
        posterPath: item.posterPath,
        releaseDate: item.releaseDate?.year.toString(),
        rating: item.voteAverage,
        listActions: TitleListActions(context, ref, item),
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
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.getResponsiveHorizontalPadding(context),
      ),
      onHeaderTap: onHeaderTap,
    );
  }

  Widget _buildTitle(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.getResponsiveHorizontalPadding(context),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onHeaderTap,
        child: MouseRegion(
          cursor: onHeaderTap != null
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: AppTheme.textWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onHeaderTap != null) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
