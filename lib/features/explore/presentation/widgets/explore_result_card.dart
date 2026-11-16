import 'package:cinemuse_app/features/media/domain/search_result.dart';
import 'package:cinemuse_app/features/profile/application/title_marks_provider.dart';
import 'package:cinemuse_app/features/media/presentation/media_details_screen.dart';
import 'package:cinemuse_app/features/media/presentation/person_details_screen.dart';
import 'package:cinemuse_app/features/profile/presentation/widgets/title_list_actions.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/l10n/app_localizations.dart';
import 'package:cinemuse_app/shared/widgets/media_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One Explore result: a movie, a TV show or a person.
class ExploreResultCard extends ConsumerWidget {
  final SearchResult result;

  const ExploreResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unknown = AppLocalizations.of(context)!.commonUnknown;

    switch (result) {
      case PersonResult(:final person):
        // No list actions: a person is not a title, so the card must not
        // offer "Add to watchlist" (it would save the TV show with this ID).
        return MediaCard(
          title: person.name ?? unknown,
          posterPath: person.profilePath,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PersonDetailsScreen(personId: person.id),
            ),
          ),
        );
      case TitleResult(:final title):
        final appLanguage = ref.watch(
          settingsProvider.select((s) => s.appLanguage),
        );
        return MediaCard(
          title: title.getLocalizedTitle(appLanguage) ?? unknown,
          posterPath: title.posterPath,
          releaseDate: title.releaseDate?.year.toString(),
          rating: title.voteAverage,
          marks: ref.watch(
            titleMarksProvider((
              tmdbId: title.tmdbId,
              mediaType: title.mediaType,
              place: MarksPlace.anywhere,
            )),
          ),
          listActions: TitleListActions(context, ref, title),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MediaDetailsScreen(
                mediaId: title.tmdbId.toString(),
                mediaType: title.mediaType.name,
              ),
            ),
          ),
        );
    }
  }
}
