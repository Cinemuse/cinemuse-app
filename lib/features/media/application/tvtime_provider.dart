import 'package:cinemuse_app/features/media/data/tvtime_service_provider.dart';
import 'package:cinemuse_app/features/media/domain/tvtime_comment.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Args for the TVTime comments provider.
///
/// Supply the most specific ID you have:
/// - For a **series**: `tvdbId` only.
/// - For a **movie**: `imdbId` only.
/// - For an **episode**: `tvdbId` + `season` + `episode`.
typedef TvTimeCommentsArgs = ({
  MediaKind type,
  int? tvdbId,
  String? imdbId,
  int? season,
  int? episode,
});

/// Fetches TVTime comments on demand for any supported entity type.
///
/// Returns an empty list (not an error) if comments cannot be loaded.
/// Errors from the service are surfaced as [AsyncError] for UI handling.
final tvTimeCommentsProvider = FutureProvider.family<
    List<TvTimeComment>,
    TvTimeCommentsArgs>((ref, args) async {
  final service = ref.read(tvTimeServiceProvider);

  switch (args.type) {
    case MediaKind.tv:
      final tvdbId = args.tvdbId;
      if (tvdbId == null) return [];
      return service.fetchSeriesComments(tvdbId);

    case MediaKind.movie:
      final imdbId = args.imdbId;
      if (imdbId == null) return [];
      return service.fetchMovieComments(imdbId);

    case MediaKind.episode:
      final tvdbId = args.tvdbId;
      final season = args.season;
      final episode = args.episode;
      if (tvdbId == null || season == null || episode == null) return [];
      return service.fetchEpisodeComments(
        tvdbId,
        season: season,
        episode: episode,
      );
  }
});
