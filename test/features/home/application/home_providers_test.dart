import 'package:cinemuse_app/core/data/server_addresses_model.dart';
import 'package:cinemuse_app/core/data/server_addresses_repository.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/home/application/home_providers.dart';
import 'package:cinemuse_app/features/home/domain/sport_tv_event.dart';
import 'package:cinemuse_app/features/media/application/watch_history_store.dart';
import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/features/media/domain/watch_history.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cinemuse_app/core/application/provider_retry.dart';

/// Answers each `load()` with the next result: a list, or a failure.
class _FakeSitesRepository implements ServerAddressesRepository {
  final List<Object> results;

  _FakeSitesRepository(this.results);

  @override
  Future<ServerAddresses> load() async {
    final next = results.removeAt(0);
    if (next is AppFailure) throw next;
    return next as ServerAddresses;
  }

  @override
  Future<ServerAddresses> fetchFromServer() => load();
}

SportTvEvent _event(String name, DateTime? at) => SportTvEvent(
  dateTime: at,
  sportName: name,
  description: '',
  channels: const [],
);

void main() {
  group('sportScheduleProvider site list (STR-08)', () {
    ProviderContainer container(List<Object> results) {
      final c = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          serverAddressesRepositoryProvider.overrideWithValue(
            _FakeSitesRepository(results),
          ),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('no sport address in the list: an empty schedule', () async {
      final c = container([ServerAddresses.empty]);

      expect(await c.read(sportScheduleProvider.future), isEmpty);
    });

    test('the Home row does not keep a failed list for the scrapers', () async {
      final c = container([
        const NetworkFailure('offline'),
        ServerAddresses({
          ServerAddress.movieSite.key: 'https://movies.example',
        }),
      ]);
      // Home stays on screen, so its row keeps listening.
      c.listen(sportScheduleProvider, (_, _) {});
      await expectLater(
        c.read(sportScheduleProvider.future),
        throwsA(isA<NetworkFailure>()),
      );
      await Future<void>.delayed(Duration.zero);

      final sites = await c.read(serverAddressesProvider.future);
      expect(sites.baseUrl(ServerAddress.movieSite), 'https://movies.example');
    });
  });

  group('upcomingSportEvents', () {
    final now = DateTime(2026, 10, 11, 20);

    test('drops events that started more than 3 hours ago', () {
      final result = upcomingSportEvents([
        _event('yesterday', DateTime(2026, 10, 10, 21)),
        _event('long ago today', DateTime(2026, 10, 11, 16, 59)),
        _event('still on', DateTime(2026, 10, 11, 18)),
        _event('later', DateTime(2026, 10, 11, 22)),
      ], now);

      expect(result.map((e) => e.sportName), ['still on', 'later']);
    });

    test('sorts by start time and keeps events without a time last', () {
      final result = upcomingSportEvents([
        _event('no time', null),
        _event('late', DateTime(2026, 10, 12, 9)),
        _event('early', DateTime(2026, 10, 11, 21)),
      ], now);

      expect(result.map((e) => e.sportName), ['early', 'late', 'no time']);
    });
  });

  group('Home rows leave out what was finished or dropped', () {
    MediaItem title(int id, MediaKind kind) =>
        MediaItem(tmdbId: id, mediaType: kind, updatedAt: DateTime.utc(2026));

    WatchHistory history(int id, MediaKind kind, WatchStatus? status) =>
        WatchHistory(
          userId: 'user-a',
          tmdbId: id,
          mediaType: kind,
          status: status,
          lastWatchedAt: DateTime.utc(2026),
        );

    final row = FutureProvider<List<MediaItem>>(
      (ref) async => [
        title(1, MediaKind.movie),
        title(1, MediaKind.tv),
        title(2, MediaKind.tv),
        title(3, MediaKind.movie),
        title(4, MediaKind.tv),
      ],
    );

    test('finished and dropped go, watching and untouched stay', () async {
      final c = ProviderContainer(
        retry: noProviderRetry,
        overrides: [
          shownWatchHistoryProvider.overrideWithValue(
            AsyncData({
              for (final h in [
                history(1, MediaKind.movie, WatchStatus.completed),
                history(2, MediaKind.tv, WatchStatus.dropped),
                history(3, MediaKind.movie, WatchStatus.watching),
                history(4, MediaKind.tv, null),
              ])
                h.titleKey: h,
            }),
          ),
        ],
      );
      addTearDown(c.dispose);
      c.listen(unseenHomeTitlesProvider(row), (_, _) {});
      await c.read(row.future);

      final shown = c.read(unseenHomeTitlesProvider(row)).value!;

      // The series sharing the finished film's id stays.
      expect(shown.map((t) => '${t.mediaType.name}-${t.tmdbId}'), [
        'tv-1',
        'movie-3',
        'tv-4',
      ]);
    });
  });
}
