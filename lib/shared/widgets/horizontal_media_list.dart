import 'package:flutter/material.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:cinemuse_app/features/media/presentation/details/media_details_screen.dart';

class HorizontalMediaList extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
        height: 100,
        child: Center(child: Text("No content available", style: TextStyle(color: Colors.white54))),
      );
    }

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
              title: item.title,
              posterPath: item.posterPath,
              releaseDate: item.releaseDate?.year.toString(),
              rating: item.voteAverage,
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => MediaDetailsScreen(
                    mediaId: item.tmdbId.toString(),
                    mediaType: item.mediaType.name,
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
