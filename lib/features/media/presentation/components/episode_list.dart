import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:cinemuse_app/features/video_player/presentation/video_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cinemuse_app/core/presentation/theme/app_theme.dart';

class EpisodeList extends ConsumerWidget {
  final int tmdbId;
  final int seasonNumber;

  const EpisodeList({
    super.key,
    required this.tmdbId,
    required this.seasonNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seasonAsync = ref.watch(seasonDetailsProvider((tmdbId: tmdbId, seasonNumber: seasonNumber)));

    return seasonAsync.when(
      data: (data) {
        if (data == null) return const SizedBox.shrink();

        final episodes = data['episodes'] as List<dynamic>;

        return ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: episodes.length,
          separatorBuilder: (context, index) => Divider(color: AppTheme.textWhite.withOpacity(0.12)),
          itemBuilder: (context, index) {
            final episode = episodes[index];
            final stillPath = episode['still_path'];
            final imageUrl = stillPath != null ? "https://image.tmdb.org/t/p/w300$stillPath" : null;
            final epNumber = episode['episode_number'];
            final name = episode['name'];
            final overview = episode['overview'];
            final runtime = episode['runtime'];

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Episode Image / Play Button
                  GestureDetector(
                    onTap: () {
                       Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(
                            queryId: tmdbId.toString(), 
                            type: 'tv',
                            season: seasonNumber,
                            episode: epNumber,
                          ),
                        ));
                    },
                    child: Container(
                      width: 140,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.textWhite.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        image: imageUrl != null ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover) : null,
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.45), borderRadius: BorderRadius.circular(20)),
                          child: const Icon(Icons.play_arrow, color: AppTheme.textWhite),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Episode Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$epNumber. $name",
                          style: const TextStyle(color: AppTheme.textWhite, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (runtime != null)
                          Text(
                            "${runtime}m",
                            style: TextStyle(color: AppTheme.textWhite.withOpacity(0.6), fontSize: 12),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          overview ?? "No description.",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  
                  // Check Button (future)
                  IconButton(
                    icon: Icon(Icons.check_circle_outline, color: AppTheme.textWhite.withOpacity(0.3)),
                    onPressed: () {
                      // Toggle watched
                    },
                  )
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, s) => Center(child: Text("Error loading season $seasonNumber", style: TextStyle(color: Theme.of(context).colorScheme.error))),
    );
  }
}
