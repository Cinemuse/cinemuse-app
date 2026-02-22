import 'package:flutter/material.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';
import 'package:cinemuse_app/shared/widgets/app_browser.dart';
import 'package:cinemuse_app/shared/widgets/bento_box.dart';
import 'package:cinemuse_app/shared/widgets/hover_scale.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VideosCarousel extends StatelessWidget {
  final Map<String, dynamic>? videos;
  final String className;

  const VideosCarousel({
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

    return BentoBox(
      title: 'Visual Archives',
      icon: Icons.movie_filter,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none, // Allow scale to "bleed" out
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Room for scale
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: trailers.map((trailer) {
              final key = trailer['key'];
              final name = trailer['name'] ?? '';

              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: _VideoCard(
                  youtubeKey: key,
                  name: name,
                  onTap: () {
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(
                          queryId: key,
                          type: 'youtube',
                        ),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  final String youtubeKey;
  final String name;
  final VoidCallback onTap;

  const _VideoCard({
    required this.youtubeKey,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 320,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: HoverScale(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CachedNetworkImage(
                          imageUrl: 'https://img.youtube.com/vi/$youtubeKey/mqdefault.jpg',
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(color: Colors.white10),
                          errorWidget: (context, url, error) => Container(color: Colors.white10),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30),
                          ),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                maxLines: 2,
                textAlign: TextAlign.left,
                overflow: TextOverflow.ellipsis,
                style: DesktopTypography.bodySecondary.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textWhite,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
