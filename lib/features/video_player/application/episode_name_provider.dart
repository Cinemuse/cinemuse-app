import 'package:cinemuse_app/features/media/application/details_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An episode's name from TMDB's season details, for the player's top bar
/// when the caller didn't pass one (REV-291): the hero's Play button,
/// Continue Watching and the watch history only know the numbers. The season
/// is usually cached already by the details page. `null` when TMDB has no name.
final episodeNameProvider = FutureProvider.autoDispose
    .family<String?, ({int tmdbId, int season, int episode})>((
      ref,
      args,
    ) async {
      final episodes = await ref.watch(
        seasonEpisodesProvider((
          tmdbId: args.tmdbId,
          seasonNumber: args.season,
        )).future,
      );
      for (final item in episodes ?? const []) {
        if (item.episodeNumber == args.episode) {
          final name = item.name?.trim();
          return (name == null || name.isEmpty) ? null : name;
        }
      }
      return null;
    });
