import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/application/own_reviews_provider.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/own_review.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:cinemuse_app/features/profile/application/profile_providers.dart';
import 'package:cinemuse_app/features/profile/application/watch_history_view_provider.dart';
import 'package:cinemuse_app/features/profile/domain/watch_history_filter.dart';
import 'package:cinemuse_app/features/profile/domain/watch_history_view.dart';
import 'package:cinemuse_app/features/settings/application/settings_service.dart';
import 'package:cinemuse_app/features/settings/domain/user_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

class _FakeSettingsNotifier extends SettingsNotifier {
  @override
  UserSettings build() => const UserSettings();
}

WatchHistory _watch(
  int id,
  MediaKind kind,
  DateTime at, {
  String? title,
  WatchStatus status = WatchStatus.completed,
  int? season,
  int? episode,
  int progress = 0,
  double? rating,
}) => WatchHistory(
  userId: 'user-a',
  tmdbId: id,
  mediaType: kind,
  status: status,
  lastWatchedAt: at,
  season: season,
  episode: episode,
  progressSeconds: progress,
  media: MediaItem(
    tmdbId: id,
    mediaType: kind,
    titleEn: title ?? 'Title $id',
    voteAverage: rating,
    updatedAt: DateTime.utc(2026),
  ),
);

void main() {
  ProviderContainer container({
    Future<List<WatchHistory>> Function()? logs,
    List<WatchHistory> local = const [],
  }) {
    final c = ProviderContainer(
      retry: noProviderRetry,
      overrides: [
        watchLogsProvider.overrideWith((ref) => logs!()),
        watchHistoryStreamProvider.overrideWith((ref) => Stream.value(local)),
        settingsProvider.overrideWith(_FakeSettingsNotifier.new),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// Waits for the logs and the local history, then reads the view.
  Future<WatchHistoryView> view(
    ProviderContainer c, [
    WatchHistoryFilter filter = const WatchHistoryFilter(),
  ]) async {
    final sub = c.listen(watchHistoryViewProvider(filter), (_, _) {});
    addTearDown(sub.close);
    await c.read(watchHistoryStreamProvider.future);
    await c.read(watchLogsProvider.future).catchError((_) => <WatchHistory>[]);
    final result = c.read(watchHistoryViewProvider(filter));
    // The error as the screen gets it (requireValue would wrap it).
    if (result case AsyncError(:final error, :final stackTrace)) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    return result.requireValue;
  }

  OwnReview rated(int id, MediaKind kind, int rating) => OwnReview(
    tmdbId: id,
    mediaType: kind,
    rating: rating,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 12);
  final yesterday = today.subtract(const Duration(days: 1));
  final lastYear = DateTime(now.year - 1, 3, 10, 12);
  const timeline = WatchHistoryFilter(viewMode: HistoryViewMode.timeline);

  group('the Ratings view', () {
    const ratingsView = WatchHistoryFilter(viewMode: HistoryViewMode.ratings);

    /// The tiers as `score: [ids]`, highest first as the provider gives them.
    Future<List<String>> tiers(
      List<WatchHistory> logs,
      List<OwnReview> reviews, {
      List<WatchHistory> local = const [],
      WatchHistoryFilter filter = ratingsView,
    }) async {
      final c = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          watchLogsProvider.overrideWith((ref) async => logs),
          watchHistoryStreamProvider.overrideWith((ref) => Stream.value(local)),
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          allOwnReviewsProvider.overrideWith(
            (ref) async => {for (final r in reviews) r.titleKey: r},
          ),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(watchHistoryRatingsProvider(filter), (_, _) {});
      addTearDown(sub.close);
      await c.read(watchHistoryStreamProvider.future);
      await c.read(watchLogsProvider.future);
      await c.read(allOwnReviewsProvider.future);
      await Future<void>.delayed(Duration.zero);
      return [
        for (final tier
            in c.read(watchHistoryRatingsProvider(filter)).requireValue)
          '${tier.score}: ${[for (final t in tier.titles) t.tmdbId]}',
      ];
    }

    test('highest first; a score nobody got has no group', () async {
      expect(
        await tiers(
          [
            _watch(1, MediaKind.movie, today),
            _watch(2, MediaKind.movie, today),
            _watch(3, MediaKind.movie, today),
          ],
          [
            rated(1, MediaKind.movie, 2),
            rated(2, MediaKind.movie, 10),
            rated(3, MediaKind.movie, 9),
          ],
        ),
        ['10: [2]', '9: [3]', '2: [1]'],
      );
    });

    test('the sort applies inside each group', () async {
      expect(
        await tiers(
          [
            _watch(1, MediaKind.movie, yesterday, title: 'B'),
            _watch(2, MediaKind.movie, today, title: 'C'),
            _watch(3, MediaKind.movie, lastYear, title: 'A'),
          ],
          [
            rated(1, MediaKind.movie, 9),
            rated(2, MediaKind.movie, 9),
            rated(3, MediaKind.movie, 9),
          ],
          filter: ratingsView.copyWith(sortOption: HistorySortOption.title),
        ),
        ['9: [3, 1, 2]'],
      );
    });

    test('a title shows once, however many watches it has', () async {
      expect(
        await tiers(
          [
            _watch(1, MediaKind.tv, today, season: 1, episode: 2),
            _watch(1, MediaKind.tv, yesterday, season: 1, episode: 1),
          ],
          [rated(1, MediaKind.tv, 8)],
        ),
        ['8: [1]'],
      );
    });

    test('titles not rated are left out', () async {
      expect(
        await tiers(
          [
            _watch(1, MediaKind.movie, today),
            _watch(2, MediaKind.movie, today),
          ],
          [rated(1, MediaKind.movie, 7)],
        ),
        ['7: [1]'],
      );
    });

    test('a film and a series with the same number are separate', () async {
      expect(
        await tiers(
          [_watch(1, MediaKind.movie, today)],
          [rated(1, MediaKind.tv, 7)],
        ),
        isEmpty,
      );
    });

    test('a title only in progress keeps its rating hidden', () async {
      expect(
        await tiers(
          const [],
          [rated(1, MediaKind.movie, 7)],
          local: [
            _watch(
              1,
              MediaKind.movie,
              today,
              status: WatchStatus.watching,
              progress: 300,
            ),
          ],
        ),
        isEmpty,
      );
    });

    test('the filters still work', () async {
      expect(
        await tiers(
          [
            _watch(1, MediaKind.movie, today, title: 'Dune'),
            _watch(2, MediaKind.tv, today, title: 'Dark'),
            _watch(3, MediaKind.movie, today, title: 'Cats'),
          ],
          [
            rated(1, MediaKind.movie, 9),
            rated(2, MediaKind.tv, 9),
            rated(3, MediaKind.movie, 2),
          ],
          filter: ratingsView.withType(MediaKind.movie).copyWith(query: 'du'),
        ),
        ['9: [1]'],
      );
    });

    test('a failed read is an error, and the view itself is fine', () async {
      final c = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          watchLogsProvider.overrideWith(
            (ref) async => [_watch(1, MediaKind.movie, today)],
          ),
          watchHistoryStreamProvider.overrideWith((ref) => Stream.value([])),
          settingsProvider.overrideWith(_FakeSettingsNotifier.new),
          allOwnReviewsProvider.overrideWith(
            (ref) async => throw const NetworkFailure('offline'),
          ),
        ],
      );
      addTearDown(c.dispose);
      final sub = c.listen(watchHistoryRatingsProvider(ratingsView), (_, _) {});
      addTearDown(sub.close);
      await c.read(watchHistoryStreamProvider.future);
      await c.read(watchLogsProvider.future);
      await c
          .read(allOwnReviewsProvider.future)
          .catchError((_) => const <String, OwnReview>{});
      await Future<void>.delayed(Duration.zero);

      expect(c.read(watchHistoryRatingsProvider(ratingsView)).hasError, isTrue);
      expect(c.read(watchHistoryViewProvider(ratingsView)).hasValue, isTrue);
    });
  });

  group('join with the local history', () {
    test(
      'local status wins; in-progress and never-logged titles added',
      () async {
        final c = container(
          logs: () async => [_watch(1, MediaKind.tv, yesterday)],
          local: [
            _watch(
              1,
              MediaKind.tv,
              today,
              status: WatchStatus.watching,
              progress: 300,
            ),
            _watch(2, MediaKind.movie, today, status: WatchStatus.dropped),
          ],
        );
        final v = await view(c, timeline);

        expect(v.items, hasLength(3));
        final logged = v.items.firstWhere((h) => h.lastWatchedAt == yesterday);
        expect(logged.status, WatchStatus.watching);
        expect(v.items.where((h) => h.progressSeconds == 300), hasLength(1));
        expect(v.items.where((h) => h.tmdbId == 2), hasLength(1));
      },
    );

    test('logs fail: the local history alone', () async {
      final c = container(
        logs: () async => throw const NetworkFailure('offline'),
        local: [_watch(5, MediaKind.movie, today)],
      );
      final v = await view(c);
      expect(v.items.single.tmdbId, 5);
    });

    test('logs fail with no local history: the error', () async {
      final c = container(
        logs: () async => throw const NetworkFailure('offline'),
      );
      await expectLater(view(c), throwsA(isA<NetworkFailure>()));
    });
  });

  group('grid', () {
    test('one card per title, its newest watch; sorted by title', () async {
      final c = container(
        logs: () async => [
          _watch(1, MediaKind.movie, yesterday, title: 'Beta'),
          _watch(1, MediaKind.movie, today, title: 'Beta'),
          _watch(2, MediaKind.movie, lastYear, title: 'Alpha'),
        ],
      );
      final v = await view(
        c,
        const WatchHistoryFilter(sortOption: HistorySortOption.title),
      );
      expect(v.items.map((h) => h.media!.titleEn), ['Alpha', 'Beta']);
      expect(v.items.last.lastWatchedAt, today);
      expect(v.sections, isEmpty);
    });

    test('a movie and a show with the same TMDB id are two titles', () async {
      final c = container(
        logs: () async => [
          _watch(7, MediaKind.movie, today),
          _watch(7, MediaKind.tv, today),
        ],
      );
      expect((await view(c)).items, hasLength(2));
    });
  });

  test('type, status and search filter; the header counts', () async {
    final c = container(
      logs: () async => [
        _watch(1, MediaKind.movie, today, title: 'Dune'),
        _watch(2, MediaKind.movie, today, title: 'Alien'),
        _watch(3, MediaKind.tv, today, title: 'Dark', season: 1, episode: 1),
        _watch(3, MediaKind.tv, today, title: 'Dark', season: 1, episode: 1),
        _watch(3, MediaKind.tv, today, title: 'Dark', season: 2, episode: 4),
        _watch(
          4,
          MediaKind.tv,
          today,
          title: 'Lost',
          status: WatchStatus.dropped,
        ),
      ],
    );

    final movies = await view(
      c,
      const WatchHistoryFilter(type: MediaKind.movie, query: 'du'),
    );
    expect(movies.items.single.media!.titleEn, 'Dune');
    expect(movies.counts.totalMovies, 2);
    expect(movies.counts.totalSeries, 2);
    expect(movies.counts.filteredMovies, 1);

    final series = await view(
      c,
      const WatchHistoryFilter(
        type: MediaKind.tv,
        status: WatchStatus.completed,
      ),
    );
    expect(series.items.single.media!.titleEn, 'Dark');
    expect(series.counts.filteredSeries, 1);
    // The rewatch of S1 E1 counts once.
    expect(series.counts.seasons, 2);
    expect(series.counts.episodes, 2);
  });

  group('timeline', () {
    test('sections newest first, whatever the sort (REV-104)', () async {
      final c = container(
        logs: () async => [
          _watch(1, MediaKind.movie, lastYear, title: 'A'),
          _watch(2, MediaKind.movie, today, title: 'Z'),
          _watch(3, MediaKind.movie, yesterday, title: 'M'),
        ],
      );
      final v = await view(
        c,
        timeline.copyWith(sortOption: HistorySortOption.title),
      );
      expect(v.sections.map((s) => s.recentDay), [
        TimelineRecentDay.today,
        TimelineRecentDay.yesterday,
        null,
      ]);
      expect(v.sections.last.date.year, now.year - 1);
    });

    test('monthly and yearly: one section per month / year', () async {
      final c = container(
        logs: () async => [
          _watch(1, MediaKind.movie, DateTime(2024, 3, 2, 12)),
          _watch(2, MediaKind.movie, DateTime(2024, 3, 20, 12)),
          _watch(3, MediaKind.movie, DateTime(2024, 5, 1, 12)),
        ],
      );
      final monthly = await view(
        c,
        timeline.copyWith(granularity: TimelineGranularity.monthly),
      );
      expect(monthly.sections.map((s) => s.decks.length), [1, 2]);
      expect(monthly.sections.every((s) => s.recentDay == null), isTrue);

      final yearly = await view(
        c,
        timeline.copyWith(granularity: TimelineGranularity.yearly),
      );
      expect(yearly.sections.single.decks, hasLength(3));
    });

    // REV-312: sections went by the UTC day, so in Italy a watch at 00:30
    // showed under "Yesterday".
    test('a watch just after local midnight is today', () async {
      final justAfterMidnight = DateTime(now.year, now.month, now.day, 0, 30);
      final c = container(
        logs: () async => [
          _watch(1, MediaKind.movie, justAfterMidnight.toUtc()),
        ],
      );
      final v = await view(c, timeline);
      expect(v.sections.single.recentDay, TimelineRecentDay.today);
    });

    final deckCases = [
      (
        name: 'one episode',
        episodes: [(1, 3)],
        label: isA<SingleEpisodeLabel>()
            .having((l) => l.season, 'season', 1)
            .having((l) => l.episode, 'episode', 3),
      ),
      (
        name: 'one season',
        episodes: [(1, 4), (1, 2), (1, 3)],
        label: isA<EpisodeRangeLabel>()
            .having((l) => l.first, 'first', 2)
            .having((l) => l.last, 'last', 4),
      ),
      (
        name: 'two seasons',
        episodes: [(1, 8), (1, 9), (2, 1), (2, 3)],
        label: isA<TwoSeasonLabel>()
            .having((l) => l.firstEpisode, 'first episode', 8)
            .having((l) => l.lastEpisode, 'last episode', 3),
      ),
      (
        name: 'three seasons',
        episodes: [(1, 1), (2, 1), (4, 1)],
        label: isA<SeasonRangeLabel>()
            .having((l) => l.firstSeason, 'first', 1)
            .having((l) => l.lastSeason, 'last', 4),
      ),
    ];
    for (final c in deckCases) {
      test('a series deck: ${c.name}', () async {
        final container0 = container(
          logs: () async => [
            for (final (i, (season, episode)) in c.episodes.indexed)
              _watch(
                9,
                MediaKind.tv,
                today.subtract(Duration(minutes: i)),
                season: season,
                episode: episode,
              ),
          ],
        );
        final deck = (await view(
          container0,
          timeline,
        )).sections.single.decks.single;
        expect(deck.stackCount, c.episodes.length);
        expect(deck.item.lastWatchedAt, today);
        expect(deck.episodeLabel, c.label);
      });
    }

    test('movies are never stacked', () async {
      final c = container(
        logs: () async => [
          _watch(1, MediaKind.movie, today),
          _watch(1, MediaKind.movie, today.subtract(const Duration(hours: 1))),
        ],
      );
      final deck = (await view(c, timeline)).sections.single.decks.single;
      expect(deck.stackCount, 1);
      expect(deck.episodeLabel, isNull);
    });
  });

  // REV-97: the screen redid the whole join, filter and grouping on every
  // rebuild. The provider keeps its result until the history changes.
  test('the same filter reads the same view, not a new one', () async {
    final c = container(logs: () async => [_watch(1, MediaKind.movie, today)]);
    final first = await view(c, timeline);
    expect(
      identical(c.read(watchHistoryViewProvider(timeline)).requireValue, first),
      isTrue,
    );
  });
}
