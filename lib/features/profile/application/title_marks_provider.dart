import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/shared/widgets/card_marks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Where a poster is shown. A place leaves out the mark it already says:
/// inside the Watchlist every title is in it.
enum MarksPlace {
  anywhere,
  watchlist,
  favorites,

  /// The watch history: everything there was watched.
  history,

  /// The Ratings view: the score is its heading.
  ratings;

  static MarksPlace ofList(ListType type) => switch (type) {
    ListType.watchlist => watchlist,
    ListType.favorites => favorites,
    _ => anywhere,
  };
}

typedef TitleMarksKey = ({int tmdbId, MediaKind mediaType, MarksPlace place});

/// A poster's marks. Each part is watched with `select`, so a change to one
/// title redraws only that title's posters.
final titleMarksProvider = Provider.autoDispose
    .family<CardMarks, TitleMarksKey>((ref, key) {
      final titleKey = '${key.mediaType.name}-${key.tmdbId}';

      final (:hasHistory, :status) = ref.watch(
        _statusesProvider.select(
          (s) => (hasHistory: s.containsKey(titleKey), status: s[titleKey]),
        ),
      );
      final isWatchlisted = ref.watch(
        _systemListKeysProvider.select((l) => l.watchlist.contains(titleKey)),
      );
      final isFavorite = ref.watch(
        _systemListKeysProvider.select((l) => l.favorites.contains(titleKey)),
      );
      // Like the title page, a score whose watches were all removed stays
      // hidden: removing the last watch deletes the title's history row.
      final score = hasHistory
          ? ref.watch(
              allOwnReviewsProvider.select((r) => r.value?[titleKey]?.rating),
            )
          : null;

      // Completed = a film seen, or a series with every episode out seen: a
      // new episode puts the series back to "watching" (the agenda does it).
      final isWatched = status == WatchStatus.completed;

      return CardMarks(
        isWatched: isWatched && key.place != MarksPlace.history,
        ownScore: key.place == MarksPlace.ratings ? null : score,
        isWatchlisted: isWatchlisted && key.place != MarksPlace.watchlist,
        isFavorite: isFavorite && key.place != MarksPlace.favorites,
      );
    });

/// Each title in the local history (by `titleKey`) with its status.
final _statusesProvider = Provider.autoDispose<Map<String, WatchStatus?>>((
  ref,
) {
  final history = ref.watch(watchHistoryStreamProvider).value ?? const [];
  return {for (final h in history) h.titleKey: h.status};
});

/// The `titleKey`s in the Watchlist and in Favorites.
final _systemListKeysProvider =
    Provider.autoDispose<({Set<String> watchlist, Set<String> favorites})>((
      ref,
    ) {
      final lists = ref.watch(userListsProvider).value ?? const [];
      Set<String> keysOf(ListType type) => {
        for (final list in lists)
          if (list.type == type)
            for (final item in list.items)
              '${item.mediaType.name}-${item.tmdbId}',
      };
      return (
        watchlist: keysOf(ListType.watchlist),
        favorites: keysOf(ListType.favorites),
      );
    });
