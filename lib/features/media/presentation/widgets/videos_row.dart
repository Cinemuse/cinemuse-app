import 'package:flutter/material.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/carousels/generic_carousel_row.dart';
import 'package:cinemuse_app/features/media/presentation/widgets/cards/video_card.dart';

class VideosRow extends StatelessWidget {
  final Map<String, dynamic>? videos;
  final String className;

  const VideosRow({
    super.key,
    this.videos,
    this.className = '',
  });

  @override
  Widget build(BuildContext context) {
    final trailers = (videos?['results'] as List?)
        ?.where((v) => v['type'] == 'Trailer')
        .toList() ?? [];

    if (trailers.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);

    return GenericCarouselRow(
      title: 'Visual Archives',
      icon: Icons.movie_filter,
      theme: CarouselTheme.bentoBox,
      itemCount: trailers.length,
      height: 290, // Standardized BentoBox-style carousels height
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemBuilder: (context, index) {
        final trailer = trailers[index];
        final key = trailer['key'];
        final name = trailer['name'] ?? '';

        return Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: VideoCard(
            youtubeKey: key,
            name: name,
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                  builder: (context) => VideoPlayerScreen(
                    queryId: key,
                    type: 'youtube',
                    loadingMessage: l10n?.playerResolvingYoutube,
                    errorMessage: l10n?.playerErrorResolvingYoutube(''),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

