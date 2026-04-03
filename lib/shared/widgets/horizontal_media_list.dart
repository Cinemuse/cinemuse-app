import 'package:flutter/material.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';

class HorizontalMediaList extends ConsumerWidget {
  final List<MediaItem> items;
  final double height;
  final double itemWidth;
  final EdgeInsets padding;

  const HorizontalMediaList({
    super.key,
    required this.items,
    this.height = 340, // Match default MediaRow height
    this.itemWidth = 200,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text("No content available", style: TextStyle(color: Colors.white54))),
      );
    }

    final appLanguage = ref.watch(settingsProvider).appLanguage;

    return SizedBox(
      height: height,
      child: ListView.separated(
        clipBehavior: Clip.none,
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (c, i) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final item = items[index];
          return SizedBox(
            width: itemWidth,
            child: MediaCard(
              title: item.getLocalizedTitle(appLanguage) ?? 'Unknown',
              posterPath: item.posterPath,
              releaseDate: item.releaseDate?.year.toString(),
              rating: item.voteAverage,
              tmdbId: item.tmdbId,
              mediaType: item.mediaType,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MediaDetailsScreen(
                    mediaId: item.tmdbId.toString(),
                    mediaType: item.mediaType.name,
                  ),
                ));
              },
              onPlay: () {
                Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
                  builder: (_) => VideoPlayerScreen(
                    queryId: item.tmdbId.toString(),
                    type: item.mediaType.name,
                  ),
                ));
              },
            ),
          );
        },
      ),
    );
  }
}
