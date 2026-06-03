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
      title: l10n?.sectionVisualArchives ?? 'Visual Archives',
      icon: Icons.movie_filter,
      theme: CarouselTheme.bentoBox,
      itemCount: trailers.length,
      height: 250, // Adjusted to fit 16:9 thumbnail + text + scrollbar
      padding: EdgeInsets.zero, // BentoBox already provides padding, avoid double padding
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
                    episodeTitle: name,
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

