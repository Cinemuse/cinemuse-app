import 'dart:async';

import 'package:cinemuse_app/features/media/domain/media_item.dart';
import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/features/media/data/tmdb_service.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_logs_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cinemuse_app/features/media/domain/series_domain_service.dart';

import 'watch_history_fakes.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSeriesDomainService extends Mock implements SeriesDomainService {}

class _MockTmdbService extends Mock implements TmdbService {}

/// What `rpc()` returns: a builder that completes with [_result].
class _FakeRpcBuilder extends Fake implements PostgrestFilterBuilder<dynamic> {
  final Future<dynamic> _result;
  _FakeRpcBuilder(this._result);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(dynamic value) onValue, {
    Function? onError,
  }) => _result.then(onValue, onError: onError);
}

void main() {
  const userId = 'user-123';
  final seriesDetails = MediaItem(
    tmdbId: 1399,
    mediaType: MediaKind.tv,
    updatedAt: DateTime(2026),
  );

  late _MockSupabaseClient supabase;
  late _MockSeriesDomainService seriesService;
  late AppDatabase database;
  late WatchLogsRepository repository;
  // Events that make the timeline and stats reload (PERF-02).
  late int logsWritten;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(
      MediaItem(tmdbId: 0, mediaType: MediaKind.tv, updatedAt: DateTime(0)),
    );
  });

  setUp(() {
    supabase = _MockSupabaseClient();
    seriesService = _MockSeriesDomainService();
    database = AppDatabase(NativeDatabase.memory());
    final tmdb = _MockTmdbService();
    repository = WatchLogsRepository(
      supabase,
      MediaRepository(database, tmdb, supabase),
      database,
      WatchHistoryRepository(
        supabase,
        MediaRepository(database, tmdb, supabase),
        database,
      ),
      seriesService,
    );
    logsWritten = 0;
    repository.events.written.listen((_) => logsWritten++);
  });

  tearDown(() async {
    await database.close();
  });

  void stubRpc(List<Map<String, dynamic>> rows) {
    when(
      () => supabase.rpc<dynamic>(any(), params: any(named: 'params')),
    ).thenAnswer((_) => _FakeRpcBuilder(Future.value(rows)));
  }

  Map<String, dynamic> capturedParams() =>
      verify(
            () => supabase.rpc<dynamic>(
              'log_episodes',
              params: captureAny(named: 'params'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  Map<String, dynamic> remoteRow({
    required String status,
    required int season,
    required int episode,
  }) => {
    'user_id': userId,
    'tmdb_id': 1399,
    'media_type': 'tv',
    'season': season,
    'episode': episode,
    'status': status,
    'progress_seconds': 0,
    'total_duration': 0,
    'watch_count': 1,
    'last_watched_at': '2026-10-09T18:00:00+00:00',
  };

  Future<void> seedLocalRow(String mediaType) => database.upsertWatchHistory(
    LocalWatchHistoriesCompanion.insert(
      userId: userId,
      tmdbId: 1399,
      mediaType: mediaType,
      status: 'watching',
      season: Value(mediaType == 'tv' ? 1 : 0),
      episode: Value(mediaType == 'tv' ? 1 : 0),
      // In the future, as rows synced before REV-178 was fixed can be.
      lastWatchedAt: DateTime.now().add(const Duration(hours: 2)),
    ),
  );

  group('mark episodes as watched', () {
    test(
      'is one log_episodes rpc, with the next episode and UTC time',
      () async {
        when(
          () => seriesService.getNextEpisode(seriesDetails, 1, 3),
        ).thenReturn((
          next: NextEpisodeInfo(season: 1, episode: 4),
          isAired: true,
        ));
        stubRpc([remoteRow(status: 'watching', season: 1, episode: 4)]);
        await seedLocalRow('tv');

        await repository.logMultipleEpisodes(
          userId: userId,
          tmdbId: 1399,
          // Not in order: the next episode follows the highest one.
          episodes: [
            (season: 1, episode: 3),
            (season: 1, episode: 1),
            (season: 1, episode: 2),
          ],
          series: seriesDetails,
          loggedAt: DateTime.utc(2026, 10, 9, 18).toLocal(),
        );

        expect(capturedParams(), {
          'p_tmdb_id': 1399,
          'p_episodes': [
            {'season': 1, 'episode': 3},
            {'season': 1, 'episode': 1},
            {'season': 1, 'episode': 2},
          ],
          // REV-178: UTC with "Z", not local time without an offset.
          'p_logged_at': '2026-10-09T18:00:00.000Z',
          'p_next_season': 1,
          'p_next_episode': 4,
          'p_next_aired': true,
        });
        // Separate table requests are what made it non-atomic.
        verifyNever(() => supabase.from(any()));

        // The server decides (REV-179); the local copy follows its answer even
        // though the old local row looked newer.
        final local = await database.getWatchHistory(userId);
        expect(local.single.status, 'watching');
        expect(local.single.episode, 4);
        expect(
          local.single.lastWatchedAt.toUtc(),
          DateTime.utc(2026, 10, 9, 18),
        );
        await pumpEventQueue();
        expect(logsWritten, 1);
      },
    );

    // REV-264: specials are extras; Continue Watching goes back to the show.
    test(
      'specials: moves on from the highest regular episode logged',
      () async {
        when(() => supabase.from('watch_logs')).thenAnswer(
          (_) => FakeQueryBuilder([
            {'season': 2, 'episode': 4},
          ]),
        );
        when(
          () => seriesService.getNextEpisode(seriesDetails, 2, 4),
        ).thenReturn((
          next: NextEpisodeInfo(season: 2, episode: 5),
          isAired: true,
        ));
        stubRpc([remoteRow(status: 'watching', season: 2, episode: 5)]);

        await repository.logMultipleEpisodes(
          userId: userId,
          tmdbId: 1399,
          episodes: [(season: 0, episode: 1), (season: 0, episode: 2)],
          series: seriesDetails,
        );

        final params = capturedParams();
        expect((params['p_next_season'], params['p_next_episode']), (2, 5));
        expect(params['p_next_aired'], isTrue);
      },
    );

    test('specials with no regular episode logged: S1 E1 is next', () async {
      // Only specials logged: the highest row is a special.
      when(() => supabase.from('watch_logs')).thenAnswer(
        (_) => FakeQueryBuilder([
          {'season': 0, 'episode': 1},
        ]),
      );
      when(() => seriesService.getNextEpisode(seriesDetails, 1, 0)).thenReturn((
        next: NextEpisodeInfo(season: 1, episode: 1),
        isAired: true,
      ));
      stubRpc([remoteRow(status: 'watching', season: 1, episode: 1)]);

      await repository.logMultipleEpisodes(
        userId: userId,
        tmdbId: 1399,
        episodes: [(season: 0, episode: 2)],
        series: seriesDetails,
      );

      final params = capturedParams();
      expect((params['p_next_season'], params['p_next_episode']), (1, 1));
    });

    test('without series details or a date', () async {
      stubRpc([remoteRow(status: 'completed', season: 2, episode: 5)]);

      await repository.logMultipleEpisodes(
        userId: userId,
        tmdbId: 1399,
        episodes: [(season: 2, episode: 5)],
      );

      expect(capturedParams(), {
        'p_tmdb_id': 1399,
        'p_episodes': [
          {'season': 2, 'episode': 5},
        ],
        'p_logged_at': null,
        'p_next_season': null,
        'p_next_episode': null,
        'p_next_aired': false,
      });
      verifyNever(() => seriesService.getNextEpisode(any(), any(), any()));
    });

    test('a movie with the same id is left alone (REV-177)', () async {
      stubRpc([remoteRow(status: 'completed', season: 1, episode: 1)]);
      await seedLocalRow('movie');
      await seedLocalRow('tv');

      await repository.logMultipleEpisodes(
        userId: userId,
        tmdbId: 1399,
        episodes: [(season: 1, episode: 1)],
      );

      final local = await database.getWatchHistory(userId);
      final movie = local.singleWhere((h) => h.mediaType == 'movie');
      expect(movie.status, 'watching');
      expect(local.singleWhere((h) => h.mediaType == 'tv').status, 'completed');
    });

    test('a server error becomes an AppFailure and keeps the cache', () async {
      when(
        () => supabase.rpc<dynamic>(any(), params: any(named: 'params')),
      ).thenAnswer(
        (_) => _FakeRpcBuilder(
          Future.error(const PostgrestException(message: 'boom', code: '500')),
        ),
      );
      await seedLocalRow('tv');

      await expectLater(
        repository.logMultipleEpisodes(
          userId: userId,
          tmdbId: 1399,
          episodes: [(season: 1, episode: 1)],
        ),
        throwsA(isA<ServerFailure>()),
      );
      final local = await database.getWatchHistory(userId);
      expect(local.single.status, 'watching');
      await pumpEventQueue();
      expect(logsWritten, 0);
    });
  });
}
