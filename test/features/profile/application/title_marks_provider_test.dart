import 'package:cinemuse_app/core/application/provider_retry.dart';
import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/lists_providers.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/application/title_marks_provider.dart';
import 'package:cinemuse_app/features/profile/domain/user_list.dart';
import 'package:cinemuse_app/shared/widgets/card_marks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUserListsNotifier extends UserListsNotifier {
  _FakeUserListsNotifier(this._lists);
  final List<UserList> _lists;

  @override
  Stream<List<UserList>> build() => Stream.value(_lists);
}

WatchHistory _history(int id, MediaKind kind, WatchStatus status) =>
    WatchHistory(
      userId: 'user-a',
      tmdbId: id,
      mediaType: kind,
      status: status,
      lastWatchedAt: DateTime.utc(2026),
    );

UserList _list(ListType type, List<(int, MediaKind)> titles) => UserList(
  id: type.name,
  userId: 'user-a',
  name: type.name,
  type: type,
  createdAt: DateTime.utc(2026),
  items: [
    for (final (id, kind) in titles)
      UserListItem(
        listId: type.name,
        mediaType: kind,
        tmdbId: id,
        addedAt: DateTime.utc(2026),
      ),
  ],
);

OwnReview _rated(int id, MediaKind kind, int rating) => OwnReview(
  tmdbId: id,
  mediaType: kind,
  rating: rating,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

void main() {
  const film = 1;
  const finishedSeries = 2;
  const halfSeries = 3;
  const unwatchedFilm = 4;
  const ratedNoWatches = 5;

  Future<CardMarks> marksOf(
    int id,
    MediaKind kind, {
    MarksPlace place = MarksPlace.anywhere,
  }) async {
    final c = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        watchHistoryStreamProvider.overrideWith(
          (ref) => Stream.value([
            _history(film, MediaKind.movie, WatchStatus.completed),
            _history(finishedSeries, MediaKind.tv, WatchStatus.completed),
            // One episode of ten: still watching.
            _history(halfSeries, MediaKind.tv, WatchStatus.watching),
          ]),
        ),
        userListsProvider.overrideWith(
          () => _FakeUserListsNotifier([
            _list(ListType.watchlist, [(film, MediaKind.movie)]),
            _list(ListType.favorites, [(film, MediaKind.movie)]),
            // Same id, other kind: not this title.
            _list(ListType.custom, [(unwatchedFilm, MediaKind.movie)]),
          ]),
        ),
        allOwnReviewsProvider.overrideWith(
          (ref) async => {
            for (final r in [
              _rated(film, MediaKind.movie, 8),
              _rated(halfSeries, MediaKind.tv, 6),
              _rated(ratedNoWatches, MediaKind.movie, 9),
            ])
              r.titleKey: r,
          },
        ),
      ],
    );
    addTearDown(c.dispose);
    final key = (tmdbId: id, mediaType: kind, place: place);
    final sub = c.listen(titleMarksProvider(key), (_, _) {});
    addTearDown(sub.close);
    await c.read(watchHistoryStreamProvider.future);
    await c.read(userListsProvider.future);
    await c.read(allOwnReviewsProvider.future);
    await Future<void>.delayed(Duration.zero);
    return c.read(titleMarksProvider(key));
  }

  test('a watched film: tick, score, bookmark and heart', () async {
    expect(
      await marksOf(film, MediaKind.movie),
      const CardMarks(
        isWatched: true,
        ownScore: 8,
        isWatchlisted: true,
        isFavorite: true,
      ),
    );
  });

  test('a series up to date gets the tick', () async {
    expect((await marksOf(finishedSeries, MediaKind.tv)).isWatched, isTrue);
  });

  test('a series half watched: no tick, its score still shows', () async {
    expect(
      await marksOf(halfSeries, MediaKind.tv),
      const CardMarks(ownScore: 6),
    );
  });

  test('a title never touched shows nothing', () async {
    expect(await marksOf(unwatchedFilm, MediaKind.movie), CardMarks.none);
    // The film in the lists has the same id as a series that isn't.
    expect(await marksOf(film, MediaKind.tv), CardMarks.none);
  });

  test('a score whose watches were all removed stays hidden', () async {
    expect(await marksOf(ratedNoWatches, MediaKind.movie), CardMarks.none);
  });

  test('each place leaves out the mark it already says', () async {
    expect(
      (await marksOf(
        film,
        MediaKind.movie,
        place: MarksPlace.watchlist,
      )).isWatchlisted,
      isFalse,
    );
    expect(
      (await marksOf(
        film,
        MediaKind.movie,
        place: MarksPlace.favorites,
      )).isFavorite,
      isFalse,
    );
    expect(
      await marksOf(film, MediaKind.movie, place: MarksPlace.history),
      const CardMarks(ownScore: 8, isWatchlisted: true, isFavorite: true),
    );
    expect(
      await marksOf(film, MediaKind.movie, place: MarksPlace.ratings),
      const CardMarks(isWatched: true, isWatchlisted: true, isFavorite: true),
    );
  });

  test('a custom list hides nothing', () {
    expect(MarksPlace.ofList(ListType.custom), MarksPlace.anywhere);
    expect(MarksPlace.ofList(ListType.watchlist), MarksPlace.watchlist);
    expect(MarksPlace.ofList(ListType.favorites), MarksPlace.favorites);
  });
}
