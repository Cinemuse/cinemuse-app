import 'dart:async';

import 'package:cinemuse_app/core/data/database.dart';
import 'package:cinemuse_app/core/error/app_failure.dart';
import 'package:cinemuse_app/core/services/media/tmdb_service.dart';
import 'package:cinemuse_app/features/media/application/series_domain_service.dart';
import 'package:cinemuse_app/features/media/data/media_repository.dart';
import 'package:cinemuse_app/features/media/data/watch_history_repository.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// `from('watch_logs')`: the "highest logged episode" read.
class _FakeLogsQuery extends Fake implements SupabaseQueryBuilder {
  final PostgrestMap? _highestLog;
  _FakeLogsQuery(this._highestLog);

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) =>
      _FakeLogsFilter(_highestLog);
}

class _FakeLogsFilter extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  final PostgrestMap? _highestLog;
  _FakeLogsFilter(this._highestLog);

  @override
  PostgrestFilterBuilder<PostgrestList> eq(String column, Object value) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) => this;

  @override
  PostgrestTransformBuilder<PostgrestList> limit(
    int count, {
    String? referencedTable,
  }) => this;

  @override
  PostgrestTransformBuilder<PostgrestMap?> maybeSingle() =>
      _FakeSingle(_highestLog);
}

class _FakeSingle extends Fake
    implements PostgrestTransformBuilder<PostgrestMap?> {
  final PostgrestMap? _value;
  _FakeSingle(this._value);

  @override
  Future<R> then<R>(
    FutureOr<R> Function(PostgrestMap? value) onValue, {
    Function? onError,
  }) => Future.value(_value).then(onValue, onError: onError);
}

void main() {
  const userId = 'user-123';

  late _MockSupabaseClient supabase;
  late _MockSeriesDomainService seriesService;
  late _MockTmdbService tmdb;
  late AppDatabase database;
  late WatchHistoryRepository repository;

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  setUp(() {
    supabase = _MockSupabaseClient();
    seriesService = _MockSeriesDomainService();
    tmdb = _MockTmdbService();
    database = AppDatabase(NativeDatabase.memory());
    repository = WatchHistoryRepository(
      supabase,
      MediaRepository(database, tmdb, supabase),
      database,
      seriesService,
      tmdb,
    );
  });

  tearDown(() async {
    await database.close();
  });

  void stubRpc(List<Map<String, dynamic>> rows) {
    when(
      () => supabase.rpc<dynamic>(any(), params: any(named: 'params')),
    ).thenAnswer((_) => _FakeRpcBuilder(Future.value(rows)));
  }

  Map<String, dynamic> capturedParams(String function) =>
      verify(
            () => supabase.rpc<dynamic>(
              function,
              params: captureAny(named: 'params'),
            ),
          ).captured.single
          as Map<String, dynamic>;

  Map<String, dynamic> remoteRow({
    required String mediaType,
    required String status,
    int season = 0,
    int episode = 0,
  }) => {
    'user_id': userId,
    'tmdb_id': 1399,
    'media_type': mediaType,
    'season': season,
    'episode': episode,
    'status': status,
    'progress_seconds': 0,
    'total_duration': 0,
    'watch_count': 1,
    'last_watched_at': '2026-10-10T12:00:00+00:00',
  };

  Future<void> seedLocalRow(String mediaType) => database.upsertWatchHistory(
    LocalWatchHistoriesCompanion.insert(
      userId: userId,
      tmdbId: 1399,
      mediaType: mediaType,
      season: const Value(1),
      episode: const Value(1),
      status: 'watching',
      progressSeconds: const Value(600),
      lastWatchedAt: DateTime.now(),
    ),
  );

  Future<String> localStatus(String mediaType) async =>
      (await database.getWatchHistory(
        userId,
      )).singleWhere((h) => h.mediaType == mediaType).status;

  group('cancel a rewatch', () {
    test('movie: one cancel_rewatch rpc, the show is left alone', () async {
      stubRpc([remoteRow(mediaType: 'movie', status: 'completed')]);
      await seedLocalRow('movie');
      await seedLocalRow('tv');

      await repository.cancelRewatch(userId, 1399, 'movie');

      expect(capturedParams('cancel_rewatch'), {
        'p_tmdb_id': 1399,
        'p_media_type': 'movie',
        'p_next_season': null,
        'p_next_episode': null,
        'p_next_aired': false,
      });
      // Separate table writes are what made it non-atomic.
      verifyNever(() => supabase.from(any()));
      expect(await localStatus('movie'), 'completed');
      // REV-177: a show with the same id is a different title.
      expect(await localStatus('tv'), 'watching');
    });

    test('show: passes the episode after the highest logged one', () async {
      when(
        () => supabase.from('watch_logs'),
      ).thenAnswer((_) => _FakeLogsQuery({'season': 1, 'episode': 3}));
      when(
        () => tmdb.getMediaDetails('1399', 'tv'),
      ).thenAnswer((_) async => {'seasons': <dynamic>[]});
      when(() => seriesService.getNextEpisode(any(), 1, 3)).thenReturn((
        next: NextEpisodeInfo(season: 1, episode: 4),
        isAired: true,
      ));
      stubRpc([
        remoteRow(mediaType: 'tv', status: 'watching', season: 1, episode: 4),
      ]);
      await seedLocalRow('tv');

      await repository.cancelRewatch(userId, 1399, 'tv');

      expect(capturedParams('cancel_rewatch'), {
        'p_tmdb_id': 1399,
        'p_media_type': 'tv',
        'p_next_season': 1,
        'p_next_episode': 4,
        'p_next_aired': true,
      });
      final local = (await database.getWatchHistory(userId)).single;
      expect((local.season, local.episode, local.progressSeconds), (1, 4, 0));
    });

    test('show: TMDB down → still one rpc, with no next episode', () async {
      when(
        () => supabase.from('watch_logs'),
      ).thenAnswer((_) => _FakeLogsQuery({'season': 2, 'episode': 8}));
      when(
        () => tmdb.getMediaDetails(any(), any()),
      ).thenThrow(const NetworkFailure('offline'));
      stubRpc([
        remoteRow(mediaType: 'tv', status: 'completed', season: 2, episode: 8),
      ]);
      await seedLocalRow('tv');

      await repository.cancelRewatch(userId, 1399, 'tv');

      // The server then marks the highest episode as completed (REV-180).
      expect(capturedParams('cancel_rewatch')['p_next_season'], isNull);
      expect(await localStatus('tv'), 'completed');
    });
  });

  group('clear progress', () {
    test('one clear_progress rpc; the returned row is cached', () async {
      stubRpc([remoteRow(mediaType: 'movie', status: 'completed')]);
      await seedLocalRow('movie');
      await seedLocalRow('tv');

      await repository.clearProgress(
        userId: userId,
        tmdbId: 1399,
        mediaType: 'movie',
      );

      expect(capturedParams('clear_progress'), {
        'p_tmdb_id': 1399,
        'p_media_type': 'movie',
      });
      verifyNever(() => supabase.from(any()));
      // REV-229: a movie seen before keeps its row, as "completed".
      expect(await localStatus('movie'), 'completed');
      expect(await localStatus('tv'), 'watching');
    });

    test('no row returned → only that title is removed locally', () async {
      stubRpc([]);
      await seedLocalRow('movie');
      await seedLocalRow('tv');

      await repository.clearProgress(
        userId: userId,
        tmdbId: 1399,
        mediaType: 'tv',
      );

      final local = await database.getWatchHistory(userId);
      expect(local.map((h) => h.mediaType), ['movie']);
    });

    test('a server error becomes an AppFailure and keeps the cache', () async {
      when(
        () => supabase.rpc<dynamic>(any(), params: any(named: 'params')),
      ).thenAnswer(
        (_) => _FakeRpcBuilder(
          Future.error(const PostgrestException(message: 'boom', code: '500')),
        ),
      );
      await seedLocalRow('movie');

      await expectLater(
        repository.clearProgress(
          userId: userId,
          tmdbId: 1399,
          mediaType: 'movie',
        ),
        throwsA(isA<ServerFailure>()),
      );
      expect(await localStatus('movie'), 'watching');
    });
  });
}
