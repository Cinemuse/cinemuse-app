import 'package:cinemuse_app/features/explore/presentation/widgets/media_type_selector.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/person_details_screen.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:flutter/material.dart';

/// One Explore result (a TMDB `discover` / popular people map): a movie,
/// a TV show or a person.
class ExploreResultCard extends StatelessWidget {
  final Map<String, dynamic> media;
  final MediaType type;

  const ExploreResultCard({super.key, required this.media, required this.type});

  @override
  Widget build(BuildContext context) {
    final title =
        media['title'] ??
        media['name'] ??
        AppLocalizations.of(context)!.commonUnknown;
    final id = media['id'] as int;

    if (type == MediaType.person) {
      // No tmdbId / mediaType: a person is not a title, so the card must not
      // offer "Add to watchlist" (it would save the TV show with this ID).
      return MediaCard(
        title: title,
        posterPath: media['profile_path'],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PersonDetailsScreen(personId: id)),
        ),
      );
    }

    final kind = type == MediaType.movie ? MediaKind.movie : MediaKind.tv;
    return MediaCard(
      title: title,
      posterPath: media['poster_path'],
      releaseDate: media['release_date'] ?? media['first_air_date'],
      rating: (media['vote_average'] as num?)?.toDouble(),
      tmdbId: id,
      mediaType: kind,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              MediaDetailsScreen(mediaId: id.toString(), mediaType: kind.name),
        ),
      ),
    );
  }
}
