import 'package:cinemuse_app/features/explore/domain/explore_type.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/person_details_screen.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/title_list_actions.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One Explore result (a TMDB `discover` / popular people map): a movie,
/// a TV show or a person.
class ExploreResultCard extends ConsumerWidget {
  final Map<String, dynamic> media;
  final ExploreType type;

  const ExploreResultCard({super.key, required this.media, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title =
        media['title'] ??
        media['name'] ??
        AppLocalizations.of(context)!.commonUnknown;
    final id = media['id'] as int;

    if (type == ExploreType.person) {
      // No list actions: a person is not a title, so the card must not
      // offer "Add to watchlist" (it would save the TV show with this ID).
      return MediaCard(
        title: title,
        posterPath: media['profile_path'],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PersonDetailsScreen(personId: id)),
        ),
      );
    }

    final kind = type == ExploreType.movie ? MediaKind.movie : MediaKind.tv;
    return MediaCard(
      title: title,
      posterPath: media['poster_path'],
      releaseDate: media['release_date'] ?? media['first_air_date'],
      rating: (media['vote_average'] as num?)?.toDouble(),
      // The type comes from the Explore tab, not guessed from the map.
      listActions: TitleListActions(
        context,
        ref,
        MediaItem.fromTmdbMap({...media, 'media_type': kind.name}),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              MediaDetailsScreen(mediaId: id.toString(), mediaType: kind.name),
        ),
      ),
    );
  }
}
